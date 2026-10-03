import SwiftUI

/// Плавающая кнопка оплаты (правый нижний угол).
struct PayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(buttonBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
        }
        .accessibilityLabel("Оплатить")
        .accessibilityHint("Открывает симуляцию Apple Pay")
    }

    private var buttonBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            Rectangle()
                .fill(Color.white.opacity(0.12))
        }
    }
}
