import SwiftUI
import UIKit

// MARK: - Цвет из hex

extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255.0
            green = Double((value >> 8) & 0xFF) / 255.0
            blue = Double(value & 0xFF) / 255.0
        } else if cleaned.count == 3 {
            red = Double((value >> 8) & 0xF) / 15.0
            green = Double((value >> 4) & 0xF) / 15.0
            blue = Double(value & 0xF) / 15.0
        } else {
            red = 1.0
            green = 1.0
            blue = 1.0
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}

// MARK: - Метрики стопки

enum CardMetrics {
    static let cornerRadius: CGFloat = 10
    static let horizontalInset: CGFloat = 16

    /// Peek-интервал стопки: 80pt (72pt на 375pt-устройствах).
    static func peek(forWidth width: CGFloat) -> CGFloat {
        width <= 375 ? 72 : 80
    }
}

// MARK: - Лицо карты

struct CardFace: View {
    let card: WalletCard
    /// Обложка, ещё не сохранённая на диск (живое превью в форме добавления).
    var inMemoryImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            cardBody
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .frame(height: card.type.cardHeight)
    }

    private var cardBody: some View {
        ZStack(alignment: .topLeading) {
            background
            scrim
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous))
        .overlay(alignment: .top) { topHairline }
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var background: some View {
        Group {
            if let image = inMemoryImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let path = card.coverImagePath, let image = ImageStore.load(relativePath: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: card.gradientColors.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    /// Затемняющий градиент (снизу вверх, 0.0 → 0.55) для читаемости текста.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.0), location: 0.0),
                .init(color: .black.opacity(0.55), location: 1.0)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Text(card.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                NetworkBadge(network: card.network)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text(card.maskedNumber)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.65), radius: 3, x: 0, y: 1)

                HStack(alignment: .center, spacing: 12) {
                    if !card.displayHolder.isEmpty {
                        Text(card.displayHolder)
                            .font(.system(size: 13, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .shadow(color: .black.opacity(0.65), radius: 3, x: 0, y: 1)
                    }
                    Spacer(minLength: 8)
                    if !card.expiry.isEmpty {
                        Text(card.expiry)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.65), radius: 3, x: 0, y: 1)
                    }
                }
            }
        }
        .padding(16)
    }

    private var topHairline: some View {
        RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
    }

    private var accessibilitySummary: String {
        var parts = [card.title, card.type.title, card.maskedNumber]
        if let balance = card.balance {
            parts.append(balance.moneyString())
        }
        return parts.joined(separator: ", ")
    }
}

// Логотип платёжной сети

struct NetworkBadge: View {
    let network: CardNetwork

    var body: some View {
        Group {
            switch network {
            case .none:
                EmptyView()
            case .visa:
                Text("VISA")
                    .font(.system(size: 17, weight: .heavy))
                    .italic()
                    .foregroundColor(.white)
            case .amex:
                Text("AMEX")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
            case .mir:
                Text("МИР")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
            case .mastercard:
                HStack(spacing: -8) {
                    Circle()
                        .fill(Color(hex: "EB001B"))
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(Color(hex: "F79E1B").opacity(0.9))
                        .frame(width: 22, height: 22)
                }
                .frame(width: 32, height: 22)
            }
        }
        .accessibilityHidden(network == .none)
        .accessibilityLabel(network.title)
    }
}
