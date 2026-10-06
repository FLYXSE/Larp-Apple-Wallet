import SwiftUI
import LocalAuthentication
import Combine
import Foundation
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

/// Стейт-машина симуляции оплаты:
/// idle → awaitingDoublePress → faceID → holdNearReader → success
///
/// Стадия `faceID` — **настоящий системный Face ID** через `LAContext.evaluatePolicy`.
/// Настоящий промпт показывается всегда, когда биометрия доступна.
/// По умолчанию `requireFaceID = true`: без успеха биометрии платёж не идёт.
/// Симулятор / без enrolled биометрии — короткая анимация глифа + fallback
/// (или ошибка «Face ID недоступен» при включённом «Требовать Face ID»).
final class PaymentFlowController: ObservableObject {
    @Published private(set) var stage: PaymentStage = .idle
    @Published private(set) var selectedCardID: UUID?

    var onFinished: (() -> Void)?

    private weak var store: WalletStore?
    private var settings = AppSettings()

    private let tiltDetector = MotionTiltDetector()
    private var volumeObserver: VolumeButtonObserver?

    private var holdTimeoutTimer: Timer?
    private var faceIDWorkItem: DispatchWorkItem?
    private var biometricWaitWorkItem: DispatchWorkItem?
    private var failureResetWorkItem: DispatchWorkItem?
    private var autoCloseWorkItem: DispatchWorkItem?
    private var laContext: LAContext?

    private var biometricResult: (succeeded: Bool, available: Bool)?
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

    // MARK: - Face ID (настоящий системный промпт LAContext)

    private func enterFaceID() {
        stage = .faceID
        Haptics.doublePress()
        biometricResult = nil

        let context = LAContext()
        laContext = context
        var error: NSError?
        // Симулятор / без enrolled биометрии — глиф + fallback.
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricResult = (succeeded: false, available: false)
            faceIDWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.faceIDFallbackFinished()
            }
            faceIDWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
            return
        }

        // Настоящий системный экран биометрии поверх приложения.
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Подтвердите оплату в Wallet"
        ) { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self = self, self.isRunning, self.stage == .faceID else { return }
                self.biometricResult = (succeeded: success, available: true)
                self.finishFaceID(with: (succeeded: success, available: true))
            }
        }

        // Если пользователь свернул системный Face ID без результата.
        faceIDWorkItem?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self = self, self.isRunning, self.stage == .faceID, self.biometricResult == nil else {
                return
            }
            self.finishFaceID(with: (succeeded: false, available: true))
        }
        faceIDWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeout)
    }

    private func faceIDFallbackFinished() {
        guard isRunning, stage == .faceID else { return }
        if settings.requireFaceID {
            enterFailure("Face ID недоступен")
        } else {
            enterHoldNearReader()
        }
    }

    private func finishFaceID(with result: (succeeded: Bool, available: Bool)) {
        guard isRunning, stage == .faceID else { return }
        faceIDWorkItem?.cancel()
        faceIDWorkItem = nil
        laContext = nil

        if settings.requireFaceID {
            guard result.available, result.succeeded else {
                enterFailure(result.available ? "Попробуйте снова" : "Face ID недоступен")
                return
            }
        }
        enterHoldNearReader()
    }

    // MARK: - Стадии

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
        laContext = nil
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
        PaymentSound.playSuccessChime()

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
        laContext = nil
    }

    private func teardown() {
        isRunning = false
        teardownSensorsAndTimers()
        autoCloseWorkItem?.cancel()
        autoCloseWorkItem = nil
        failureResetWorkItem?.cancel()
        failureResetWorkItem = nil
        stopVolumeObserver()
    }
}
