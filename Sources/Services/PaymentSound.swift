import AVFoundation
import Foundation

/// Короткий звуковой сигнал успеха оплаты (двухнотный «динь», как у Apple Pay).
enum PaymentSound {
    private static var player: AVAudioPlayer?

    static func playSuccessChime() {
        guard let data = try? makeChimeWAV(), !data.isEmpty else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        player = try? AVAudioPlayer(data: data)
        player?.volume = 0.85
        player?.prepareToPlay()
        player?.play()
    }

    // MARK: - Генерация WAV (PCM 16-bit mono 44.1 kHz)

    private static func makeChimeWAV() throws -> Data {
        let sampleRate: Double = 44_100
        let totalDuration: Double = 0.55
        let sampleCount = Int(sampleRate * totalDuration)

        // Восходящая пара нот + лёгкий акцент — «успешная оплата».
        let notes: [(frequency: Double, start: Double, duration: Double, gain: Double)] = [
            (523.25, 0.00, 0.18, 0.40), // C5
            (659.25, 0.11, 0.32, 0.38), // E5
            (783.99, 0.20, 0.35, 0.28)  // G5
        ]

        var samples = [Int16](repeating: 0, count: sampleCount)

        for note in notes {
            let startSample = max(0, Int(note.start * sampleRate))
            let endSample = min(sampleCount, startSample + Int(note.duration * sampleRate))
            for i in startSample..<endSample {
                let t = Double(i - startSample) / sampleRate
                // Быстрое затухание + мягкий attack.
                let attack = min(1.0, t / 0.012)
                let decay = exp(-t * 7.5)
                let value = sin(2 * Double.pi * note.frequency * t) * attack * decay * note.gain
                let clamped = max(-1.0, min(1.0, value))
                samples[i] = Int16(clamped * Double(Int16.max))
            }
        }

        return wrapPCM16Mono(samples, sampleRate: sampleRate)
    }

    private static func wrapPCM16Mono(_ samples: [Int16], sampleRate: Double) -> Data {
        let byteRate = UInt32(sampleRate) * 2 // mono * 16-bit
        let dataSize = UInt32(samples.count * 2)
        let riffSize = 36 + dataSize
        let sampleRateI = UInt32(sampleRate)

        var data = Data(capacity: 44 + samples.count * 2)

        func appendASCII(_ s: String) {
            data.append(contentsOf: Array(s.utf8))
        }
        func appendUInt32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendUInt16(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendInt16(_ v: Int16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        appendASCII("RIFF")
        appendUInt32(riffSize)
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendUInt32(16) // PCM chunk size
        appendUInt16(1)  // PCM
        appendUInt16(1)  // mono
        appendUInt32(sampleRateI)
        appendUInt32(byteRate)
        appendUInt16(2)  // block align
        appendUInt16(16) // bits per sample
        appendASCII("data")
        appendUInt32(dataSize)

        for s in samples {
            appendInt16(s)
        }

        return data
    }
}
