import AVFoundation
import Combine
import Foundation
import Vision

/// Реальное распознавание лица на стадии Face ID: фронтальная камера + Vision
/// (`VNDetectFaceRectangles`). Кадры обрабатываются только на устройстве —
/// ничего не сохраняется и не отправляется наружу.
///
/// Оплата продолжается, когда лицо удерживается в кадре `confirmHoldDuration`
/// секунд подряд. При недоступности камеры (симулятор, отказ в доступе)
/// контроллер оплаты переключается на классическую анимацию Face ID.
final class FaceScanner: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingAccess
        case running
        case denied
        case unavailable
    }

    /// Поток захвата — его же использует превью в `FaceCameraPreview`.
    let session = AVCaptureSession()

    @Published private(set) var status: Status = .idle
    @Published private(set) var isFacePresent = false
    @Published private(set) var isConfirmed = false
    /// Bounding box лица в координатах изображения (normalized, origin — низ-лево, как в Vision).
    @Published private(set) var faceBox: CGRect?
    /// Размер обрабатываемого кадра в пикселях — нужен для отрисовки рамки на превью.
    @Published private(set) var imageSize: CGSize = .zero

    /// Смена статуса, всегда на главной очереди.
    var onStatusChange: ((Status) -> Void)?
    /// Лицо подтверждено, на главной очереди, не более одного раза за запуск.
    var onConfirmed: (() -> Void)?

    /// Сколько секунд лицо должно удерживаться в кадре.
    private let confirmHoldDuration: TimeInterval = 0.7
    /// Минимальный интервал между запусками Vision (~10 fps достаточно).
    private let analysisInterval: TimeInterval = 0.1
    /// Нижняя граница уверенности детектора.
    private let minimumConfidence: Float = 0.3

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "Wallet.FaceScanner.session")
    private let analysisQueue = DispatchQueue(label: "Wallet.FaceScanner.analysis", qos: .userInteractive)

    private var isConfigured = false
    private var wantsRunning = false
    private var confirmedEmitted = false
    private var faceHeldSince: Date?
    private var lastAnalysisAt = Date.distantPast

    // MARK: - Публичный API

    /// Запуск сканирования. Всегда вызывается на главной очереди.
    func start() {
        wantsRunning = true
        confirmedEmitted = false
        faceHeldSince = nil
        isConfirmed = false
        isFacePresent = false
        faceBox = nil

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            runSession()
        case .notDetermined:
            setStatus(.requestingAccess)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self, self.wantsRunning else { return }
                    if granted {
                        self.runSession()
                    } else {
                        self.fail(with: .denied)
                    }
                }
            }
        case .denied, .restricted:
            fail(with: .denied)
        @unknown default:
            fail(with: .denied)
        }
    }

    /// Остановка захвата. Вызывается на главной очереди; идемпотентна.
    func stop() {
        wantsRunning = false
        faceHeldSince = nil
        setStatus(.idle)
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Сессия

    private func runSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if !self.isConfigured {
                guard self.configure() else {
                    DispatchQueue.main.async { self.fail(with: .unavailable) }
                    return
                }
                self.isConfigured = true
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
            let started = self.session.isRunning

            DispatchQueue.main.async {
                guard self.wantsRunning else {
                    self.stopSessionAsync()
                    return
                }
                if started {
                    self.setStatus(.running)
                } else {
                    self.fail(with: .unavailable)
                }
            }
        }
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            return false
        }
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else { return false }
        videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)
        session.addOutput(videoOutput)
        applyPortraitOrientation(to: videoOutput.connection(with: .video))
        return true
    }

    private func applyPortraitOrientation(to connection: AVCaptureConnection?) {
        guard let connection = connection else { return }
        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    private func stopSessionAsync() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func fail(with newStatus: Status) {
        wantsRunning = false
        faceHeldSince = nil
        setStatus(newStatus)
    }

    // MARK: - Детекция

    private func handleFrame(faceBox box: CGRect?, imageSize: CGSize) {
        self.imageSize = imageSize
        guard status == .running, !isConfirmed else { return }

        if let box = box {
            faceBox = box
            if !isFacePresent {
                isFacePresent = true
                Haptics.selection()
            }
            if faceHeldSince == nil {
                faceHeldSince = Date()
            }
            if let since = faceHeldSince, Date().timeIntervalSince(since) >= confirmHoldDuration {
                emitConfirmed()
            }
        } else {
            faceBox = nil
            isFacePresent = false
            faceHeldSince = nil
        }
    }

    private func emitConfirmed() {
        guard !confirmedEmitted else { return }
        confirmedEmitted = true
        isConfirmed = true
        onConfirmed?()
    }

    private func setStatus(_ newStatus: Status) {
        if Thread.isMainThread {
            applyStatus(newStatus)
        } else {
            DispatchQueue.main.async { [weak self] in self?.applyStatus(newStatus) }
        }
    }

    private func applyStatus(_ newStatus: Status) {
        status = newStatus
        onStatusChange?(newStatus)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FaceScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysisAt) >= analysisInterval else { return }
        lastAnalysisAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let imageSize = CGSize(
            width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
            height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        )

        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let self = self else { return }
            let faces = ((request.results as? [VNDetectedObjectObservation]) ?? [])
                .filter { $0.confidence >= self.minimumConfidence }
            let box = faces.map(\.boundingBox).max { lhs, rhs in
                (lhs.width * lhs.height) < (rhs.width * rhs.height)
            }
            DispatchQueue.main.async {
                self.handleFrame(faceBox: box, imageSize: imageSize)
            }
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        try? handler.perform([request])
    }
}
