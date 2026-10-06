import Foundation
import PhotosUI
import SwiftUI
import UIKit

// MARK: - Добавление карты

struct AddCardSheet: View {
    @EnvironmentObject private var store: WalletStore

    var body: some View {
        CardForm(onSubmit: { card in
            store.add(card)
        })
    }
}

// MARK: - Редактирование карты

struct EditCardSheet: View {
    let card: WalletCard
    @EnvironmentObject private var store: WalletStore

    var body: some View {
        CardForm(
            existing: card,
            onSubmit: { updated in
                store.update(updated)
            },
            onDelete: {
                store.delete(id: card.id)
            }
        )
    }
}

// MARK: - Форма карточки

struct CardForm: View {
    @Environment(\.dismiss) private var dismiss

    private let existing: WalletCard?
    private let onSubmit: (WalletCard) -> Void
    private let onDelete: (() -> Void)?

    @State private var title: String
    @State private var number: String
    @State private var expiry: String
    @State private var holder: String
    @State private var balanceText: String
    @State private var type: CardType
    @State private var gradient: [String]
    @State private var customColor: Color
    @State private var coverImage: UIImage?
    @State private var coverPath: String?
    @State private var pickedItem: PhotosPickerItem?
    @State private var cropSource: UIImage?
    @State private var showCropper = false
    @State private var showDeleteConfirm = false
    @State private var previewID = UUID()

    private static let presets: [[String]] = [
        ["E8E8EB", "A8A8AD", "3D3D3F"],
        ["1A1F71", "2A48B8"],
        ["EB001B", "F79E1B"],
        ["016FD0", "004A97"],
        ["0FA758", "046C38"],
        ["5E5CE6", "3634A3"],
        ["FF375F", "AF52DE"],
        ["FF9F0A", "FF6B00"]
    ]

    init(
        existing: WalletCard? = nil,
        onSubmit: @escaping (WalletCard) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existing = existing
        self.onSubmit = onSubmit
        self.onDelete = onDelete

        let digits = existing?.digits ?? ""
        _title = State(initialValue: existing?.title ?? "")
        _number = State(initialValue: Self.formatNumber(digits))
        _expiry = State(initialValue: existing?.expiry ?? "")
        _holder = State(initialValue: existing?.holder ?? "")
        _balanceText = State(initialValue: Self.numberString(from: existing?.balance))
        _type = State(initialValue: existing?.type ?? .credit)
        _gradient = State(initialValue: existing?.gradientColors ?? Self.presets[0])
        _customColor = State(initialValue: Color(hex: "5E5CE6"))
        _coverImage = State(initialValue: nil)
        _coverPath = State(initialValue: existing?.coverImagePath)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    previewSection
                    fieldsSection
                    typeSection
                    gradientSection
                    photoSection

                    if let onDelete = onDelete {
                        deleteSection(action: onDelete)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .onChange(of: number) { value in
            let formatted = Self.formatNumber(value)
            if formatted != value {
                number = formatted
            }
        }
        .onChange(of: expiry) { value in
            let formatted = Self.formatExpiry(value)
            if formatted != value {
                expiry = formatted
            }
        }
        .onChange(of: customColor) { value in
            gradient = [Self.hexString(from: value)]
        }
        .onChange(of: pickedItem) { item in
            handlePickedItem(item)
        }
        .fullScreenCover(isPresented: $showCropper) {
            cropScreen
        }
    }

    // MARK: - Верхняя панель

    private var topBar: some View {
        HStack(spacing: 12) {
            Button("Отмена") {
                dismiss()
            }
            .foregroundColor(Color(hex: "0A84FF"))
            .accessibilityLabel("Отменить")

            Spacer(minLength: 8)

            Text(existing == nil ? "Новая карта" : "Редактирование")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            Spacer(minLength: 8)

            Button("Готово") {
                save()
            }
            .fontWeight(.semibold)
            .foregroundColor(canSave ? Color(hex: "0A84FF") : Color.secondary)
            .disabled(!canSave)
            .accessibilityLabel("Сохранить карту")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Превью

    private var previewSection: some View {
        CardFace(card: draftCard, inMemoryImage: coverImage)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    // MARK: - Поля

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("ОСНОВНОЕ")

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Название карты")
                TextField("Например, Sapphire", text: $title)
                    .fieldStyle()
                    .onChange(of: title) { value in
                        if value.count > 30 {
                            title = String(value.prefix(30))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Номер карты")
                TextField("0000 0000 0000 0000", text: $number)
                    .fieldStyle(keyboard: .numberPad)
                if digits.count < 16 {
                    Text("16 цифр — подойдёт и выдуманный номер")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "636368"))
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Срок действия")
                    TextField("ММ/ГГ", text: $expiry)
                        .fieldStyle(keyboard: .numberPad)
                    if !expiry.isEmpty && !isExpiryValid {
                        Text("Формат ММ/ГГ")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "FF453A"))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Держатель")
                    TextField("IVAN IVANOV", text: $holder)
                        .fieldStyle(textAutocapitalization: .characters)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Баланс / лимит")
                TextField("1 000,00", text: $balanceText)
                    .fieldStyle(keyboard: .decimalPad)
            }
        }
        .cardSurface()
    }

    // MARK: - Тип

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ТИП КАРТЫ")
            Picker("Тип карты", selection: $type) {
                ForEach(CardType.allCases) { cardType in
                    Text(cardType.title).tag(cardType)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .cardSurface()
    }

    // MARK: - Оформление

    private var gradientSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ОФОРМЛЕНИЕ")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(Self.presets.enumerated()), id: \.offset) { _, preset in
                        Button {
                            Haptics.selection()
                            gradient = preset
                        } label: {
                            swatch(colors: preset.map { Color(hex: $0) }, isSelected: gradient == preset)
                        }
                        .accessibilityLabel("Пресет цвета")
                        .accessibilityAddTraits(gradient == preset ? .isSelected : [])
                    }

                    ColorPicker(selection: $customColor, supportsOpacity: false) {
                        swatch(colors: [customColor], isSelected: gradient.count == 1)
                    }
                    .accessibilityLabel("Свой цвет")
                }
            }
        }
        .cardSurface()
    }

    private func swatch(colors: [Color], isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 52, height: 34)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(isSelected ? 0.9 : 0.16),
                        lineWidth: 2
                    )
            )
    }

    // MARK: - Обложка

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ОБЛОЖКА")

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "2C2C2E"))
                        .frame(width: 58, height: 37)

                    if let preview = coverPreview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 58, height: 37)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "636368"))
                    }
                }
                .accessibilityHidden(true)

                Spacer(minLength: 8)

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Text(coverPreview == nil ? "Выбрать фото" : "Изменить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "0A84FF"))
                }
                .accessibilityLabel("Выбрать фото обложки из галереи")

                if coverPreview != nil {
                    Button("Убрать") {
                        coverImage = nil
                        coverPath = nil
                    }
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "FF453A"))
                    .accessibilityLabel("Убрать обложку")
                }
            }

            Text("Любое фото из галереи — после выбора его можно обрезать. Без фото карта использует градиент.")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "636368"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface()
    }

    // MARK: - Удаление

    private func deleteSection(action: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Text("Удалить карту")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Color(hex: "FF453A"))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: "1C1C1E"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .confirmationDialog(
            "Удалить карту?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                action()
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Карта и её операции будут удалены с устройства.")
        }
    }

    // MARK: - Кроп

    @ViewBuilder
    private var cropScreen: some View {
        if let source = cropSource {
            PhotoCropScreen(
                source: source,
                onDone: { cropped in
                    coverImage = cropped
                    cropSource = nil
                    showCropper = false
                },
                onCancel: {
                    cropSource = nil
                    showCropper = false
                }
            )
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    private func handlePickedItem(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            var loaded: UIImage?
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded = UIImage(data: data)
            }
            await MainActor.run {
                if let loaded = loaded {
                    cropSource = ImageStore.normalized(loaded)
                    showCropper = true
                }
                pickedItem = nil
            }
        }
    }

    // MARK: - Логика

    private var digits: String {
        number.filter { $0.isNumber }
    }

    private var coverPreview: UIImage? {
        if let coverImage = coverImage {
            return coverImage
        }
        guard let coverPath = coverPath else { return nil }
        return ImageStore.load(relativePath: coverPath)
    }

    private var isExpiryValid: Bool {
        guard expiry.count == 5 else { return false }
        let parts = expiry.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]) else { return false }
        return (1...12).contains(month) && (0...99).contains(year)
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty
            && trimmedTitle.count <= 30
            && digits.count == 16
            && isExpiryValid
    }

    private var draftCard: WalletCard {
        WalletCard(
            id: existing?.id ?? previewID,
            title: title.isEmpty ? "Название карты" : title,
            type: type,
            number: digits,
            expiry: expiry,
            holder: holder.uppercased(),
            balance: parseDecimal(balanceText),
            coverImagePath: coverPath,
            gradient: gradient,
            network: CardNetwork.infer(from: digits, type: type),
            createdAt: existing?.createdAt ?? Date(),
            lastUsedAt: existing?.lastUsedAt,
            transactions: existing?.transactions ?? [],
            sortOrder: existing?.sortOrder ?? 0
        )
    }

    private func save() {
        guard canSave else { return }

        let id = existing?.id ?? previewID
        var path = coverPath
        if let image = coverImage {
            path = ImageStore.save(image, id: id) ?? coverPath
        }
        if let oldPath = existing?.coverImagePath, oldPath != path {
            ImageStore.delete(relativePath: oldPath)
        }

        let card = WalletCard(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            number: digits,
            expiry: expiry,
            holder: holder.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            balance: parseDecimal(balanceText),
            coverImagePath: path,
            gradient: gradient,
            network: CardNetwork.infer(from: digits, type: type),
            createdAt: existing?.createdAt ?? Date(),
            lastUsedAt: existing?.lastUsedAt,
            transactions: existing?.transactions ?? [],
            sortOrder: existing?.sortOrder ?? 0
        )

        Haptics.impact(.medium)
        onSubmit(card)
        dismiss()
    }

    private func parseDecimal(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "₽", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private static func numberString(from balance: Decimal?) -> String {
        guard let balance = balance else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: balance)) ?? ""
    }

    private static func formatNumber(_ input: String) -> String {
        let digits = String(input.filter { $0.isNumber }.prefix(16))
        var result = ""
        for (index, character) in digits.enumerated() {
            if index > 0 && index % 4 == 0 {
                result.append(" ")
            }
            result.append(character)
        }
        return result
    }

    private static func formatExpiry(_ input: String) -> String {
        let digits = String(input.filter { $0.isNumber }.prefix(4))
        guard digits.count > 2 else { return digits }
        return String(digits.prefix(2)) + "/" + String(digits.suffix(2))
    }

    private static func hexString(from color: Color) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "5E5CE6"
        }
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - Мелкие элементы формы

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.7)
            .foregroundColor(Color(hex: "A0A0A5"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func sectionHeader(_ title: String) -> some View {
        SectionHeader(title: title)
    }

    func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
    }

    func fieldStyle(
        keyboard: UIKeyboardType = .default,
        textAutocapitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        font(.system(size: 17))
            .foregroundColor(.primary)
            .keyboardType(keyboard)
            .textInputAutocapitalization(textAutocapitalization)
            .disableAutocorrection(true)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func cardSurface() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
