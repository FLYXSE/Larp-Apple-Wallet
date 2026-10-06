import SwiftUI
import UIKit

/// Успешная оплата: зелёный круг с галкой (системная геометрия SF).
struct SuccessCheckView: View {
    var size: CGFloat = 64

    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "30D158"))
                .frame(width: size, height: size)

            Image(systemName: "checkmark")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .scaleEffect(appeared ? 1.0 : 0.6)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                appeared = true
            }
        }
        .accessibilityLabel("Оплата прошла успешно")
    }
}
