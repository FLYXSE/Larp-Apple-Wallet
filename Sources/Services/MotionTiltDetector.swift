import CoreMotion
import Foundation

/// Детект наклона устройства к считывателю (§7.4 ТЗ).
/// Сглаживание — EMA (α = 0.2), порог 25° с удержанием ≥ 0.7 с,
/// альтернативный путь — всплеск угловой скорости ≥ 1.2 rad/s и стабилизация.
final class MotionTiltDetector {
    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    private let alpha: Double = 0.2
    private let tiltThreshold: Double = 25.0 * .pi / 180.0
    private let holdRequired: TimeInterval = 0.7
    private let rotationSpikeThreshold: Double = 1.2
    private let rotationCalmThreshold: Double = 0.3
    private let calmRequired: TimeInterval = 0.3

    private var baselinePitch: Double?
    private var smoothedPitch: Double?
    private var tiltedSince: Date?
    private var rotationSpiked = false
    private var calmSince: Date?
    private var confirmed = false

    private(set) var isRunning = false

    var onTiltConfirmed: (() -> Void)?

    var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    func start() {
        guard isAvailable else { return }
        stop()
        confirmed = false
        baselinePitch = nil
        smoothedPitch = nil
        tiltedSince = nil
        rotationSpiked = false
        calmSince = nil

        manager.deviceMotionUpdateInterval = 0.1
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            let pitch = motion.attitude.pitch
            let rate = motion.rotationRate
            let rotation = sqrt(rate.x * rate.x + rate.y * rate.y + rate.z * rate.z)
            DispatchQueue.main.async {
                self.process(pitch: pitch, rotation: rotation)
            }
        }
        isRunning = true
    }

    func stop() {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
        isRunning = false
        baselinePitch = nil
        smoothedPitch = nil
        tiltedSince = nil
        rotationSpiked = false
        calmSince = nil
    }

    private func process(pitch: Double, rotation: Double) {
        guard isRunning, !confirmed else { return }

        if baselinePitch == nil {
            baselinePitch = pitch
            smoothedPitch = pitch
            return
        }

        let previous = smoothedPitch ?? pitch
        let smoothed = alpha * pitch + (1.0 - alpha) * previous
        smoothedPitch = smoothed

        let baseline = baselinePitch ?? pitch
        if abs(smoothed - baseline) >= tiltThreshold {
            if tiltedSince == nil {
                tiltedSince = Date()
            } else if let since = tiltedSince, Date().timeIntervalSince(since) >= holdRequired {
                confirm()
                return
            }
        } else {
            tiltedSince = nil
        }

        if rotation >= rotationSpikeThreshold {
            rotationSpiked = true
            calmSince = nil
        } else if rotationSpiked {
            if rotation <= rotationCalmThreshold {
                if calmSince == nil {
                    calmSince = Date()
                } else if let since = calmSince, Date().timeIntervalSince(since) >= calmRequired {
                    confirm()
                }
            } else {
                calmSince = nil
            }
        }
    }

    private func confirm() {
        confirmed = true
        onTiltConfirmed?()
    }
}
