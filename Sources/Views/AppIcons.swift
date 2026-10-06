import SwiftUI

/// Иконки в стиле Lucide/Tabler (наборы, которые морфит morphicons).
/// Path рисуются в сетке 24×24 со stroke — как SVG-данные иконок.
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
}

struct AppIcon: View {
    let name: AppIconName
    var size: CGFloat = 24
    var lineWidth: CGFloat = 2
    var color: Color = .white

    var body: some View {
        Canvas { context, _ in
            let scale = size / 24
            var path = Path { path in
                buildPath(&path)
            }
            if scale != 1 {
                path = path.applying(CGAffineTransform(scaleX: scale, y: scale))
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1, lineWidth * min(scale, 1.6)), lineCap: .round, lineJoin: .round)
            )
            if name == .ellipsis {
                var dots = Path()
                for x in [CGFloat(6), 12, 18] {
                    dots.addEllipse(in: CGRect(x: x - 1.6, y: 10.4, width: 3.2, height: 3.2))
                }
                if scale != 1 {
                    dots = dots.applying(CGAffineTransform(scaleX: scale, y: scale))
                }
                context.fill(dots, with: .color(color))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func buildPath(_ path: inout Path) {
        switch name {
        case .cube:
            path.move(to: CGPoint(x: 12, y: 2))
            path.addLine(to: CGPoint(x: 21, y: 7))
            path.addLine(to: CGPoint(x: 21, y: 17))
            path.addLine(to: CGPoint(x: 12, y: 22))
            path.addLine(to: CGPoint(x: 3, y: 17))
            path.addLine(to: CGPoint(x: 3, y: 7))
            path.closeSubpath()
            path.move(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 21, y: 7))
            path.move(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 3, y: 7))
            path.move(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 12, y: 22))
        case .plus:
            path.move(to: CGPoint(x: 12, y: 5))
            path.addLine(to: CGPoint(x: 12, y: 19))
            path.move(to: CGPoint(x: 5, y: 12))
            path.addLine(to: CGPoint(x: 19, y: 12))
        case .ellipsis:
            break
        case .search:
            path.addEllipse(in: CGRect(x: 3, y: 3, width: 13, height: 13))
            path.move(to: CGPoint(x: 18.5, y: 18.5))
            path.addLine(to: CGPoint(x: 22, y: 22))
        case .chevronRight:
            path.move(to: CGPoint(x: 9, y: 18))
            path.addLine(to: CGPoint(x: 15, y: 12))
            path.addLine(to: CGPoint(x: 9, y: 6))
        case .person:
            path.addEllipse(in: CGRect(x: 8, y: 3, width: 8, height: 8))
            path.move(to: CGPoint(x: 4.5, y: 21))
            path.addCurve(
                to: CGPoint(x: 19.5, y: 21),
                control1: CGPoint(x: 4.5, y: 16),
                control2: CGPoint(x: 19.5, y: 16)
            )
        case .bank:
            path.move(to: CGPoint(x: 3, y: 10))
            path.addLine(to: CGPoint(x: 21, y: 10))
            path.move(to: CGPoint(x: 5, y: 10))
            path.addLine(to: CGPoint(x: 5, y: 20))
            path.move(to: CGPoint(x: 10, y: 10))
            path.addLine(to: CGPoint(x: 10, y: 20))
            path.move(to: CGPoint(x: 14, y: 10))
            path.addLine(to: CGPoint(x: 14, y: 20))
            path.move(to: CGPoint(x: 19, y: 10))
            path.addLine(to: CGPoint(x: 19, y: 20))
            path.move(to: CGPoint(x: 12, y: 2))
            path.addLine(to: CGPoint(x: 22, y: 8))
            path.addLine(to: CGPoint(x: 2, y: 8))
            path.closeSubpath()
        case .faceID:
            path.move(to: CGPoint(x: 3, y: 7))
            path.addLine(to: CGPoint(x: 7, y: 7))
            path.move(to: CGPoint(x: 17, y: 7))
            path.addLine(to: CGPoint(x: 21, y: 7))
            path.move(to: CGPoint(x: 3, y: 17))
            path.addLine(to: CGPoint(x: 7, y: 17))
            path.move(to: CGPoint(x: 17, y: 17))
            path.addLine(to: CGPoint(x: 21, y: 17))
            path.move(to: CGPoint(x: 3, y: 11))
            path.addLine(to: CGPoint(x: 3, y: 7))
            path.move(to: CGPoint(x: 21, y: 11))
            path.addLine(to: CGPoint(x: 21, y: 7))
            path.move(to: CGPoint(x: 3, y: 13))
            path.addLine(to: CGPoint(x: 3, y: 17))
            path.move(to: CGPoint(x: 21, y: 13))
            path.addLine(to: CGPoint(x: 21, y: 17))
            path.move(to: CGPoint(x: 9, y: 10))
            path.addLine(to: CGPoint(x: 9, y: 12))
            path.move(to: CGPoint(x: 15, y: 10))
            path.addLine(to: CGPoint(x: 15, y: 12))
            path.move(to: CGPoint(x: 9, y: 16))
            path.addCurve(
                to: CGPoint(x: 15, y: 16),
                control1: CGPoint(x: 10.5, y: 18),
                control2: CGPoint(x: 13.5, y: 18)
            )
        case .creditCard:
            path.addRoundedRect(
                in: CGRect(x: 2, y: 5, width: 20, height: 14),
                cornerSize: CGSize(width: 2, height: 2)
            )
            path.move(to: CGPoint(x: 2, y: 10))
            path.addLine(to: CGPoint(x: 22, y: 10))
        case .check:
            path.move(to: CGPoint(x: 20, y: 6))
            path.addLine(to: CGPoint(x: 9, y: 17))
            path.addLine(to: CGPoint(x: 4, y: 12))
        case .xmark:
            path.move(to: CGPoint(x: 18, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 18))
            path.move(to: CGPoint(x: 6, y: 6))
            path.addLine(to: CGPoint(x: 18, y: 18))
        case .pencil:
            path.move(to: CGPoint(x: 12, y: 20))
            path.addLine(to: CGPoint(x: 12, y: 14))
            path.move(to: CGPoint(x: 18, y: 4))
            path.addLine(to: CGPoint(x: 20, y: 6))
            path.addLine(to: CGPoint(x: 8, y: 18))
            path.addLine(to: CGPoint(x: 4, y: 20))
            path.addLine(to: CGPoint(x: 6, y: 16))
            path.closeSubpath()
        case .sideButton:
            path.addRoundedRect(
                in: CGRect(x: 7, y: 2, width: 10, height: 20),
                cornerSize: CGSize(width: 4, height: 4)
            )
            path.move(to: CGPoint(x: 16, y: 12))
            path.addLine(to: CGPoint(x: 9, y: 12))
            path.move(to: CGPoint(x: 12, y: 8))
            path.addLine(to: CGPoint(x: 8, y: 12))
            path.addLine(to: CGPoint(x: 12, y: 16))
        case .refresh:
            path.addArc(
                center: CGPoint(x: 12, y: 12),
                radius: 8,
                startAngle: .degrees(-40),
                endAngle: .degrees(300),
                clockwise: false
            )
            path.move(to: CGPoint(x: 12, y: 2))
            path.addLine(to: CGPoint(x: 12, y: 6))
            path.move(to: CGPoint(x: 20, y: 12))
            path.addLine(to: CGPoint(x: 16, y: 12))
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
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Pay")
    }
}
