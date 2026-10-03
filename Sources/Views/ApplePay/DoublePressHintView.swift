import SwiftUI

/// Реплика боковой кнопки (справа от рамки) с распознаванием двойного тапа (§7.2).
struct SideButtonReplica: View {
    let isEnabled: Bool
    let onDoublePress: () -> Void

    @State private var lastTapAt: Date?
    @State private var isPressed = false
    @State private var glow = false

    var body: some View {
        Button {
            handleTap()
        } label: {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(glow ? 1.0 : (isPressed ? 0.85 : 0.45)))
                .frame(width: 4, height: 60)
                .shadow(
                    color: Color.white.opacity(glow ? 0.85 : 0),
                    radius: glow ? 10 : 0
                )
                .frame(width: 44, height: 76, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onAppear {
            // Подсказка «дважды»: двойная вспышка при входе в состояние.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                flashTwice()
            }
        }
        .accessibilityLabel("Боковая кнопка")
        .accessibilityHint("Дважды нажмите, чтобы оплатить")
    }

    private func handleTap() {
        guard isEnabled else { return }

        withAnimation(.easeOut(duration: 0.08)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.16)) {
                isPressed = false
            }
        }

        let now = Date()
        if let lastTapAt = lastTapAt, now.timeIntervalSince(lastTapAt) <= 0.4 {
            self.lastTapAt = nil
            flashTwice()
            onDoublePress()
        } else {
            lastTapAt = now
        }
    }

    private func flashTwice() {
        withAnimation(.easeOut(duration: 0.12)) {
            glow = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeIn(duration: 0.14)) {
                glow = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeOut(duration: 0.12)) {
                    glow = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.easeIn(duration: 0.14)) {
                        glow = false
                    }
                }
            }
        }
    }
}

/// Подсказка внизу шторки ожидания двойного нажатия.
struct DoublePressHintView: View {
    let text: String

    var body: some View {
        VStack(spacing: 16) {
            DoubleTapIndicator()
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

private struct DoubleTapIndicator: View {
    @State private var flash = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(flash ? 0.95 : 0.22))
                    .frame(width: 8, height: 8)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.5),
                        value: flash
                    )
            }
        }
        .onAppear {
            flash = true
        }
        .accessibilityHidden(true)
    }
}
