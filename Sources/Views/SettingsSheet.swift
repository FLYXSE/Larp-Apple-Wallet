import SwiftUI
import UIKit

struct SettingsSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var appearance: Int = 2

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Настройки")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 4)

                    currencySection
                    motionSection
                    faceIDSection
                    appearanceSection
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
            Button {
                dismiss()
            } label: {
                Text("Готово")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "0A84FF"))
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Закрыть настройки")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Секции

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("СУММА")

            VStack(alignment: .leading, spacing: 0) {
                row {
                    Text("Сумма оплаты")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                    Spacer(minLength: 12)
                    TextField("1 000,00", text: $amountText)
                        .font(.system(size: 17).monospacedDigit())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                }

                hairline

                row {
                    Text("Продавец")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                    Spacer(minLength: 12)
                    TextField("DEMO STORE", text: $settings.merchant)
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "A0A0A5"))
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.characters)
                        .frame(maxWidth: 160)
                }
            }
            .cardSurface()
        }
    }

    private var motionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("ПОВЕДЕНИЕ")

            VStack(alignment: .leading, spacing: 0) {
                row {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Кнопки громкости")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        Text("Двойное нажатие как аналог боковой кнопки")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "636368"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Toggle("", isOn: $settings.useVolumeButtons)
                        .labelsHidden()
                }
            }
            .cardSurface()
        }
    }

    private var faceIDSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("FACE ID")

            VStack(alignment: .leading, spacing: 0) {
                row {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Требовать Face ID")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        Text("Оплата идёт через системный Face ID. При включении неудача блокирует платёж")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "636368"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Toggle("", isOn: $settings.requireFaceID)
                        .labelsHidden()
                }
            }
            .cardSurface()
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ОТОБРАЖЕНИЕ")

            Picker("Вид", selection: $appearance) {
                Text("Система").tag(0)
                Text("Светлый").tag(1)
                Text("Тёмный").tag(2)
            }
            .pickerStyle(.segmented)
            .disabled(true)
            .opacity(0.7)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("О ПРИЛОЖЕНИИ")
            Text("Демо-режим: приложение ничего не списывает и не отправляет данные наружу. Реальные платежи, PassKit и NFC не используются.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "A0A0A5"))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                AppIcon(name: .refresh, size: 14, lineWidth: 2, color: Color(hex: "0A84FF"))
                Text("Wallet 1.2 · полностью офлайн")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "636368"))
            }
        }
        .cardSurface()
    }

    // MARK: - Помощники

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.7)
            .foregroundColor(Color(hex: "8E8E93"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color(hex: "262629"))
            .frame(height: 0.5)
            .padding(.leading, 14)
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
        padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
