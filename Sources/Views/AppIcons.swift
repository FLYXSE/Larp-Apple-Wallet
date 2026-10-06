import SwiftUI
import UIKit

/// Иконки на SF Symbols — правильная геометрия системы (как в Apple Pay).
enum AppIconName {
    case cube
    case plus
    case ellipsis
    case search
    case chevronRight
    case person
    case bank
    case faceID
    case creditCard
    case check
    case xmark
    case pencil
    case sideButton
    case refresh
    case phone
    case contactless
}

struct AppIcon: View {
    let name: AppIconName
    var size: CGFloat = 24
    var lineWidth: CGFloat = 2
    var color: Color = .white

    private var systemName: String {
        switch name {
        case .cube: return "cube"
        case .plus: return "plus"
        case .ellipsis: return "ellipsis"
        case .search: return "magnifyingglass"
        case .chevronRight: return "chevron.right"
        case .person: return "person"
        case .bank: return "building.columns"
        case .faceID: return "faceid"
        case .creditCard: return "creditcard"
        case .check: return "checkmark"
        case .xmark: return "xmark"
        case .pencil: return "pencil"
        case .sideButton: return "rectangle.portrait.rightthird"
        case .refresh: return "arrow.clockwise"
        case .phone: return "iphone"
        case .contactless: return "wave.3.right"
        }
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weightForName))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var weightForName: Font.Weight {
        switch name {
        case .creditCard, .faceID, .cube:
            return .medium
        case .check, .plus, .xmark:
            return .semibold
        case .chevronRight, .search:
            return .semibold
        default:
            return .regular
        }
    }
}

/// Apple-логотип (системный SF Symbol).
struct AppleMark: View {
    var size: CGFloat = 16
    var color: Color = .white

    var body: some View {
        Image(systemName: "applelogo")
            .font(.system(size: size, weight: .medium))
            .foregroundColor(color)
            .accessibilityHidden(true)
    }
}

/// Строка « Pay» в шапке шторки.
struct ApplePayTitle: View {
    var body: some View {
        HStack(spacing: 4) {
            AppleMark(size: 20)
            Text("Pay")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Pay")
    }
}

/// Стеклянная плашка (упрощённая, адаптируется к светлой/тёмной теме).
struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var tint: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint,
                                    Color.primary.opacity(0.04),
                                    Color.black.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}
