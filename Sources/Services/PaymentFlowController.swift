import Combine
import Foundation
import LocalAuthentication
import UIKit

enum PaymentStage: Equatable {
    case idle
    case awaitingDoublePress(isRetry: Bool)
    case faceID
    case holdNearReader
    case success
    case failed(String)

    var isRetry: Bool {
        if case .awaitingDoublePress(let retry) = self { return retry }
        return false
    }
}

/// Стейт-машина симуляции оплаты (§4.4 и §7 ТЗ):
/// idle → awaitingDoublePress → faceID → holdNearReader → success
/// cancel/timeout — из любого состояния.
///
/// Стадия `faceID` по умолчанию идёт через реальное распознавание лица
/// (`FaceScanner`: камера + Vision). Если камера недоступна или доступ
/// запрещён — автоматический fallback на классическую анимацию Face ID
/// (и опционально реальную `LAContext`, если включён флаг «Требовать
/// успешный Face ID»).
final class PaymentFlowController: ObservableObject {
    @Published private(set) var stage: PaymentStage = .idle
    @Published private(set) var selectedCardID: UUID?
    /// Идёт сканирование лица камерой — шторка показывает живое превью.
    @Published private(set) var isCameraScanning = false

    /// Реальное сканирование лица (фронтальная камера + Vision).
    let faceScanner = FaceScanner()

    /// Вызывается для автозакрытия шторки после успешной оплаты.
    var onFinished: (() -> Void)?

    private weak var store: WalletStore?
    private var settings = AppSettings()

    private let tiltDetector = MotionTiltDetector()
    private var volumeObserver: VolumeButtonObserver?

    /// Сколько секунд ждём лицо в кадре, прежде чем счесть проверку провальной.
    private let faceScanTimeout: TimeInterval = 15

    private var holdTimeoutTimer: Timer?
    private var faceIDWorkItem: DispatchWorkItem?
    private var biometricWaitWorkItem: DispatchWorkItem?
    private var failureResetWorkItem: DispatchWorkItem?
    private var autoCloseWorkItem: DispatchWorkItem?
    private var faceScanWorkItem: DispatchWorkItem?

    private var biometricResult: (succeeded: Bool, available: Bool)?
    private var waitingForBiometrics = false
    private var isRunning = false

    deinit {
        teardown()
    }

    // MARK: - Жизненный цикл

    func start(cardID: UUID?, cards: [WalletCard], store: WalletStore, settings: AppSettings) {
        teardown()
        self.store = store
        self.settings = settings

        let initialID = cardID ?? cards.first?.id
        selectedCardID = initialID
        if let initialID = initialID {
            store.touch(cardID: initialID)
        }

        isRunning = true
        stage = .awaitingDoublePress(isRetry: false)
        tiltDetector.onTiltConfirmed = { [weak self] in
            self?.succeed()
        }
        if settings.useVolumeButtons {
            startVolumeObserver()
        }
    }

    func stop() {
        teardown()
        stage = .idle
    }

    // MARK: - Входы

    func handleDoublePress() {
        guard isRunning, case .awaitingDoublePress = stage else { return }
        enterFaceID()
    }

    func handleFallbackHold() {
        guard isRunning, case .holdNearReader = stage, !tiltDetector.isAvailable else { return }
        succeed()
    }

    func selectAdjacentCard(offset: Int, cards: [WalletCard]) {
        guard !cards.isEmpty,
              let currentID = selectedCardID,
              let index = cards.firstIndex(where: { $0.id == currentID }) else { return }

        let count = cards.count
        let nextIndex = ((index + offset) % count + count) % count
        let nextID = cards[nextIndex].id
        guard nextID != currentID else { return }

        selectedCardID = nextID
        store?.touch(cardID: nextID)
        Haptics.selection()
    }

    // MARK: - Стадии

    private func enterFaceID() {
        stage = .faceID
        Haptics.doublePress()
        biometricResult = nil
        waitingForBiometrics = false

        if settings.useFaceScan {
            startCameraFaceScan()
        } else {
            startLegacyFaceID()
        }
    }

    /// Основной путь: реальное распознавание лица камерой.
    private func startCameraFaceScan() {
        isCameraScanning = true
        faceScanner.onConfirmed = { [weak self] in
            self?.faceScanConfirmed()
        }
        faceScanner.onStatusChange = { [weak self] status in
            self?.faceScanStatusChanged(status)
        }
        faceScanner.start()
        scheduleFaceScanTimeout()
    }

    private func faceScanStatusChanged(_ status: FaceScanner.Status) {
        guard isRunning, stage == .faceID, isCameraScanning else { return }
        switch status {
        case .denied, .unavailable:
            // Fallback: классическая анимация Face ID (+ LAContext по флагу).
            stopCameraFaceScan()
            startLegacyFaceID()
        case .idle, .requestingAccess, .running:
            break
        }
    }

    private func faceScanConfirmed() {
        guard isRunning, stage == .faceID else { return }
        stopCameraFaceScan()
        enterHoldNearReader()
    }

    private func faceScanTimedOut() {
        guard isRunning, stage == .faceID, isCameraScanning else { return }
        stopCameraFaceScan()
        enterFailure("Лицо не распознано")
    }

    private func stopCameraFaceScan() {
        faceScanWorkItem?.cancel()
        faceScanWorkItem = nil
        faceScanner.onConfirmed = nil
        faceScanner.onStatusChange = nil
        faceScanner.stop()
        isCameraScanning = false
    }

    private func scheduleFaceScanTimeout() {
        faceScanWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.faceScanTimedOut()
        }
        faceScanWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + faceScanTimeout, execute: work)
    }

    /// Fallback-путь без камеры: анимация глифа + опционально реальная LAContext.
    private func startLegacyFaceID() {
        isCameraScanning = false
        evaluateBiometrics()

        faceIDWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.faceIDAnimationFinished()
        }
        faceIDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func evaluateBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Симулятор / без Face ID — реальная проверка недоступна.
            biometricResult = (succeeded: false, available: false)
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Демо-оплата в Wallet"
        ) { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let result = (succeeded: success, available: true)
                self.biometricResult = result
                if self.waitingForBiometrics {
                    self.waitingForBiometrics = false
                    self.biometricWaitWorkItem?.cancel()
                    self.biometricWaitWorkItem = nil
                    self.finishFaceID(with: result)
                }
            }
        }
    }

    private func faceIDAnimationFinished() {
        guard isRunning, stage == .faceID else { return }

        if settings.requireFaceID {
            if let result = biometricResult {
                finishFaceID(with: result)
            } else {
                waitingForBiometrics = true
                let work = DispatchWorkItem { [weak self] in
                    guard let self = self, self.waitingForBiometrics else { return }
                    self.waitingForBiometrics = false
                    self.finishFaceID(with: (succeeded: false, available: true))
                }
                biometricWaitWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
            }
        } else {
            enterHoldNearReader()
        }
    }

    private func finishFaceID(with result: (succeeded: Bool, available: Bool)) {
        guard isRunning, stage == .faceID else { return }
        if settings.requireFaceID, result.available, !result.succeeded {
            enterFailure("Попробуйте снова")
            return
        }
        enterHoldNearReader()
    }

    private func enterHoldNearReader() {
        stage = .holdNearReader
        Haptics.impact(.light)
        tiltDetector.start()
        startHoldTimeout()
    }

    private func startHoldTimeout() {
        holdTimeoutTimer?.invalidate()
        let timer = Timer(timeInterval: 20, repeats: false) { [weak self] _ in
            self?.holdTimedOut()
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimeoutTimer = timer
    }

    private func holdTimedOut() {
        guard isRunning, stage == .holdNearReader else { return }
        tiltDetector.stop()
        stage = .awaitingDoublePress(isRetry: true)
    }

    private func enterFailure(_ message: String) {
        tiltDetector.stop()
        holdTimeoutTimer?.invalidate()
        holdTimeoutTimer = nil
        stage = .failed(message)
        Haptics.impact(.rigid)

        failureResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, case .failed = self.stage else { return }
            self.stage = .awaitingDoublePress(isRetry: true)
        }
        failureResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func succeed() {
        guard isRunning, stage == .holdNearReader else { return }
        teardownSensorsAndTimers()
        stage = .success
        Haptics.success()

        if let cardID = selectedCardID, let store = store {
            store.recordPayment(
                cardID: cardID,
                merchant: settings.merchant,
                amount: settings.amount
            )
        }

        autoCloseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.stage == .success else { return }
            self.onFinished?()
        }
        autoCloseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    // MARK: - Ресурсы

    private func startVolumeObserver() {
        let observer = VolumeButtonObserver()
        observer.onDoublePress = { [weak self] in
            self?.handleDoublePress()
        }
        observer.start()
        volumeObserver = observer
    }

    private func stopVolumeObserver() {
        volumeObserver?.stop()
        volumeObserver = nil
    }

    private func teardownSensorsAndTimers() {
        tiltDetector.stop()
        holdTimeoutTimer?.invalidate()
        holdTimeoutTimer = nil
        faceIDWorkItem?.cancel()
        faceIDWorkItem = nil
        biometricWaitWorkItem?.cancel()
        biometricWaitWorkItem = nil
        waitingForBiometrics = false
    }

    private func teardown() {
        isRunning = false
        teardownSensorsAndTimers()
        stopCameraFaceScan()
        autoCloseWorkItem?.cancel()
        autoCloseWorkItem = nil
        failureResetWorkItem?.cancel()
        failureResetWorkItem = nil
        stopVolumeObserver()
    }
}
