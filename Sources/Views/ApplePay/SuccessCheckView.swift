import SwiftUI

/// Успешная оплата: зелёный круг с галкой (§7.5).
struct SuccessCheckView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "30D158"))
                .frame(width: 64, height: 64)

            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 64, height: 64)
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
