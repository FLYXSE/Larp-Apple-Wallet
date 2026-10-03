import SwiftUI

/// Волны «приложите к считывателю».
struct NFCWaveView: View {
    @State private var animating = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .scaleEffect(animating ? 1.5 : 0.55)
                    .opacity(animating ? 0 : 0.85)
                    .animation(
                        .easeOut(duration: 1.8)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.6),
                        value: animating
                    )
            }

            Image(systemName: "wave.3.right")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .opacity(0.9)
        }
        .frame(width: 130, height: 130)
        .onAppear {
            animating = true
        }
        .accessibilityLabel("Приложите к считывателю")
    }
}
