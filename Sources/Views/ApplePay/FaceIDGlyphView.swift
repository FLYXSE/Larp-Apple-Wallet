import SwiftUI

/// Глиф Face ID: скруглённый квадрат с viewfinder-уголками и сканирующей линией.
struct FaceIDGlyphView: View {
    var animateScanLine: Bool = true

    @State private var lineTravelled = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 64, height: 64)

            ZStack {
                brackets

                if animateScanLine {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 42, height: 2)
                        .offset(y: lineTravelled ? 21 : -21)
                        .opacity(lineTravelled ? 0.25 : 1)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(width: 64, height: 64)
        .onAppear {
            guard animateScanLine else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                lineTravelled = true
            }
        }
        .accessibilityLabel("Проверка лица")
    }

    private var brackets: some View {
        ZStack {
            bracket(.topLeading)
            bracket(.topTrailing)
            bracket(.bottomLeading)
            bracket(.bottomTrailing)
        }
        .frame(width: 44, height: 44)
    }

    private func bracket(_ alignment: Alignment) -> some View {
        ZStack(alignment: alignment) {
            Rectangle()
                .fill(Color.white)
                .frame(width: 12, height: 3)
            Rectangle()
                .fill(Color.white)
                .frame(width: 3, height: 12)
        }
        .frame(width: 44, height: 44)
    }
}
