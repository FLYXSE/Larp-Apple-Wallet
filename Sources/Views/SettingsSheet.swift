import SwiftUI
import UIKit

struct SettingsSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    simulationSection
                    behaviorSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            amountText = settings.amount.moneyString(currency: "")
                .trimmingCharacters(in: .whitespaces)
        }
        .onChange(of: amountText) { value in
            if let parsed = Self.parseDecimal(value) {
                settings.amount = parsed
            }
        }
    }

    // MARK: - Панель

    private var topBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 8)

            Text("Настройки")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Закрыть настройки")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Секции

    private var simulationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("СИМУЛЯЦИЯ ОПЛАТЫ")

            VStack(alignment: .leading, spacing: 6) {
                Text("Сумма")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "A0A0A5"))
                HStack(spacing: 8) {
                    TextField("1 000,00", text: $amountText)
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(Color(hex: "2C2C2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("₽")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "A0A0A5"))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Сумма демо-оплаты в рублях")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Продавец")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "A0A0A5"))
                TextField("DEMO STORE", text: $settings.merchant)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color(hex: "2C2C2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .cardSurface()
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("ПОВЕДЕНИЕ")
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $settings.useFaceScan) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сканировать лицо камерой")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        Text("Стадия Face ID идёт через фронтальную камеру (Vision). При отказе в доступе включается классическая анимация")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "636368"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 12)
            }

            Rectangle()
                .fill(Color(hex: "262629"))
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $settings.requireFaceID) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Требовать успешный Face ID")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        Text("Для legacy-пути (глиф/системный Face ID). При камерном сканировании оплата идёт после подтверждения лица в кадре")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "636368"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 12)
            }

            Rectangle()
                .fill(Color(hex: "262629"))
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $settings.useVolumeButtons) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Аппаратные кнопки громкости")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        Text("Двойное нажатие кнопки громкости как аналог боковой кнопки (только на устройстве)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "636368"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .cardSurface()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("О ПРИЛОЖЕНИИ")
            Text("Демо-режим: приложение ничего не списывает и не отправляет данные наружу. Реальные платежи, PassKit и NFC не используются.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "A0A0A5"))
                .fixedSize(horizontal: false, vertical: true)
            Text("Кошелёк 1.1 · полностью офлайн")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "636368"))
        }
        .cardSurface()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.7)
            .foregroundColor(Color(hex: "A0A0A5"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func parseDecimal(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "₽", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }
}

private extension View {
    func cardSurface() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
