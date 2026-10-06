import SwiftUI
import UIKit

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
                .shadow(color: Color(hex: "0A84FF").opacity(0.45), radius: 14, x: 0, y: 6)
        }
        .accessibilityLabel("Оплатить")
        .accessibilityHint("Открывает симуляцию Apple Pay")
    }

    private var buttonBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "0A84FF"),
                Color(hex: "0057B8")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
