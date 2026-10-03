import Combine
import Foundation

struct AppSettings: Codable, Equatable {
    var amount: Decimal
    var merchant: String
    var requireFaceID: Bool
    var useVolumeButtons: Bool

    init(
        amount: Decimal = Decimal(string: "1000.00") ?? 1000,
        merchant: String = "DEMO STORE",
        requireFaceID: Bool = false,
        useVolumeButtons: Bool = false
    ) {
        self.amount = amount
        self.merchant = merchant
        self.requireFaceID = requireFaceID
        self.useVolumeButtons = useVolumeButtons
    }
}

final class SettingsStore: ObservableObject {
    @Published var amount: Decimal {
        didSet { save() }
    }

    @Published var merchant: String {
        didSet { save() }
    }

    @Published var requireFaceID: Bool {
        didSet { save() }
    }

    @Published var useVolumeButtons: Bool {
        didSet { save() }
    }

    private let fileURL: URL

    init(directory: URL? = nil) {
        let base: URL
        if let directory = directory {
            base = directory
        } else {
            base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        self.fileURL = base.appendingPathComponent("settings.json")

        let defaults = AppSettings()
        var loaded = defaults
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            loaded = decoded
        }

        self.amount = loaded.amount
        self.merchant = loaded.merchant
        self.requireFaceID = loaded.requireFaceID
        self.useVolumeButtons = loaded.useVolumeButtons
    }

    var current: AppSettings {
        AppSettings(
            amount: amount,
            merchant: merchant.isEmpty ? "DEMO STORE" : merchant,
            requireFaceID: requireFaceID,
            useVolumeButtons: useVolumeButtons
        )
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(current)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Локальная запись не удалась — настройки остаются в памяти.
        }
    }
}
