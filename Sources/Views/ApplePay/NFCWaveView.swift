import SwiftUI

/// Волны «приложите к считывателю» + иконка iPhone (как на скриншоте).
struct NFCWaveView: View {
    @State private var animating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "0A84FF"),
                            Color(hex: "0057B8")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color(hex: "0A84FF").opacity(0.55), radius: 18, x: 0, y: 8)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .scaleEffect(animating ? 1.55 : 0.7)
                    .opacity(animating ? 0 : 0.75)
                    .animation(
                        .easeOut(duration: 1.8)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.6),
                        value: animating
                    )
            }

            Image(systemName: "iphone")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(.white)
                .accessibilityHidden(true)
        }
        .frame(width: 88, height: 88)
        .onAppear {
            animating = true
        }
        .accessibilityLabel("Приложите к считывателю")
    }
}

/// Иконка contactless-расплаты в стеклянной плашке.
struct ContactlessBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            AppIcon(name: .contactless, size: 20, lineWidth: 2.2, color: .white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.12))
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text("Бесконтактная")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("оплата")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Бесконтактная оплата")
    }
}
