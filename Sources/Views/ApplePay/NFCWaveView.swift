import SwiftUI
import UIKit

/// Нижняя плашка: iPhone в синем круге + текст «Поднесите к считывателю».
/// Без стеклянной подсказки «Проведите оплату с iPhone».
struct NFCWaveView: View {
    @State private var animating = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color(hex: "0A84FF").opacity(0.45), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .scaleEffect(animating ? 1.45 : 0.75)
                    .opacity(animating ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.8)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.6),
                        value: animating
                    )
            }

            Circle()
                .stroke(Color(hex: "0A84FF"), lineWidth: 3)
                .frame(width: 72, height: 72)

            Image(systemName: "iphone")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(Color(hex: "0A84FF"))
        }
        .frame(width: 96, height: 96)
        .onAppear {
            animating = true
        }
        .accessibilityLabel("Приложите к считывателю")
    }
}

/// Иконка contactless (для мест, где нужна отдельная плашка).
struct ContactlessBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            AppIcon(name: .contactless, size: 20, color: Color(hex: "0A84FF"))

            VStack(alignment: .leading, spacing: 1) {
                Text("Бесконтактная")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text("оплата")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Бесконтактная оплата")
    }
}
