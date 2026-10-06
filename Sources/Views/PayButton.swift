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
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color(hex: "0A84FF").opacity(0.55), radius: 16, x: 0, y: 8)
        }
        .accessibilityLabel("Оплатить")
        .accessibilityHint("Открывает симуляцию Apple Pay")
    }

    private var buttonBackground: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "0A84FF").opacity(0.95))
            Circle()
                .fill(Color.white.opacity(0.10))
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}
