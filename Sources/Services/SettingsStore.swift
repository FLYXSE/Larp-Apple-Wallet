import Combine
import Foundation
import SwiftUI

struct AppSettings: Codable, Equatable {
    var amount: Decimal
    var merchant: String
    var requireFaceID: Bool
    var useVolumeButtons: Bool
    /// 0 — системная тема iPhone, 1 — светлая, 2 — тёмная.
    var appearance: Int

    init(
        amount: Decimal = Decimal(string: "1000.00") ?? 1000,
        merchant: String = "DEMO STORE",
        requireFaceID: Bool = true,
        useVolumeButtons: Bool = false,
        appearance: Int = 0
    ) {
        self.amount = amount
        self.merchant = merchant
        self.requireFaceID = requireFaceID
        self.useVolumeButtons = useVolumeButtons
        self.appearance = appearance
    }

    /// Обратно совместимое декодирование: старый settings.json без новых ключей.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decode(Decimal.self, forKey: .amount)
        merchant = try container.decode(String.self, forKey: .merchant)
        requireFaceID = try container.decodeIfPresent(Bool.self, forKey: .requireFaceID) ?? true
        useVolumeButtons = try container.decodeIfPresent(Bool.self, forKey: .useVolumeButtons) ?? false
        appearance = try container.decodeIfPresent(Int.self, forKey: .appearance) ?? 0
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

    @Published var appearance: Int {
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

        var loaded = AppSettings()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            loaded = decoded
        }

        self.amount = loaded.amount
        self.merchant = loaded.merchant
        self.requireFaceID = loaded.requireFaceID
        self.useVolumeButtons = loaded.useVolumeButtons
        self.appearance = loaded.appearance
    }

    /// nil — следовать системной теме iPhone.
    var colorScheme: ColorScheme? {
        switch appearance {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var current: AppSettings {
        AppSettings(
            amount: amount,
            merchant: merchant.isEmpty ? "DEMO STORE" : merchant,
            requireFaceID: requireFaceID,
            useVolumeButtons: useVolumeButtons,
            appearance: appearance
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
