import SwiftUI
import UIKit

/// Глиф Face ID — системный SF Symbol (правильная геометрия, как на скриншотах).
struct FaceIDGlyphView: View {
    var animateScanLine: Bool = false
    var size: CGFloat = 56
    var color: Color = Color(hex: "0A84FF")

    @State private var pulsing = false

    var body: some View {
        Image(systemName: "faceid")
            .font(.system(size: size, weight: .regular))
            .foregroundColor(color)
            .frame(width: size + 16, height: size + 16)
            .scaleEffect(pulsing && animateScanLine ? 1.06 : 1.0)
            .opacity(pulsing && animateScanLine ? 0.85 : 1)
            .onAppear {
                guard animateScanLine else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            .accessibilityLabel("Face ID")
    }
}
