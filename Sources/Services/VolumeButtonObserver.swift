import MediaPlayer
import UIKit

/// Опциональный аппаратный триггер (§7.2 ТЗ): двойное нажатие кнопки
/// громкости переводит симуляцию в состояние Face ID.
/// На симуляторе и при недоступности — тихо не работает, без крашей.
final class VolumeButtonObserver {
    private var volumeView: MPVolumeView?
    private var sliderObservation: NSKeyValueObservation?
    private var lastChangeAt: Date?
    private var originalVolume: Float?

    private(set) var isObserving = false

    var onDoublePress: (() -> Void)?

    var isSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    func start() {
        guard isSupported, !isObserving else { return }

        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        if let window = Self.activeWindow() {
            window.addSubview(view)
        }
        volumeView = view

        guard let slider = Self.volumeSlider(of: view) else {
            view.removeFromSuperview()
            volumeView = nil
            return
        }

        originalVolume = slider.value
        sliderObservation = slider.observe(\.value, options: [.new, .old]) { [weak self] _, _ in
            self?.volumeDidChange()
        }
        lastChangeAt = nil
        isObserving = true
    }

    func stop() {
        isObserving = false
        sliderObservation?.invalidate()
        sliderObservation = nil
        let slider = volumeView.flatMap { Self.volumeSlider(of: $0) }
        if let slider = slider, let original = originalVolume {
            slider.value = original
        }
        volumeView?.removeFromSuperview()
        volumeView = nil
        originalVolume = nil
        lastChangeAt = nil
    }

    private func volumeDidChange() {
        guard isObserving else { return }
        guard let last = lastChangeAt else {
            lastChangeAt = Date()
            return
        }
        if Date().timeIntervalSince(last) <= 0.4 {
            lastChangeAt = nil
            onDoublePress?()
        } else {
            lastChangeAt = Date()
        }
    }

    private static func volumeSlider(of view: MPVolumeView) -> UISlider? {
        view.subviews.compactMap { $0 as? UISlider }.first
    }

    private static func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
