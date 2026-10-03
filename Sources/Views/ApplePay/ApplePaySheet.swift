import SwiftUI

/// Полноэкранная симуляция оплаты (§4.4 ТЗ): чёрный overlay, а не системный sheet.
struct ApplePaySheet: View {
    let cardID: UUID?
    let onDismiss: () -> Void

    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var settings: SettingsStore

    @StateObject private var flow = PaymentFlowController()
    @State private var dragX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if flow.stage == .success {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeAfterSuccess)
                }

                VStack(spacing: 0) {
                    header

                    Spacer(minLength: 0)

                    cardArea(screenHeight: geo.size.height)

                    Spacer(minLength: 0)

                    stageContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 36)
                }
                .padding(.horizontal, 16)

                if case .awaitingDoublePress = flow.stage {
                    SideButtonReplica(isEnabled: true) {
                        flow.handleDoublePress()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, geo.size.height * 0.24)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: startFlow)
        .onDisappear {
            // Датчики и таймеры выключаются при закрытии шторки.
            flow.stop()
        }
        .simultaneousGesture(dismissGesture)
        .animation(.easeInOut(duration: 0.3), value: flow.stage)
        .preferredColorScheme(.dark)
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("Отмена") {
                cancel()
            }
            .foregroundColor(Color(hex: "0A84FF"))
            .accessibilityLabel("Отменить оплату")

            Spacer(minLength: 8)

            VStack(spacing: 2) {
                Text(settings.merchant)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(settings.amount.moneyString())
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundColor(Color(hex: "A0A0A5"))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("Демо")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "636368"))
                .frame(width: 44, alignment: .trailing)
                .accessibilityLabel("Демо-режим, реальная оплата не выполняется")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Карта

    @ViewBuilder
    private func cardArea(screenHeight: CGFloat) -> some View {
        let cards = store.cards
        let lift: CGFloat = flow.stage == .holdNearReader ? -screenHeight * 0.08 : 0

        if let card = selectedCard {
            CardFace(card: card)
                .offset(x: dragX, y: lift)
                .simultaneousGesture(cardSwipe(cards: cards))
                .onLongPressGesture(minimumDuration: 1.5) {
                    flow.handleFallbackHold()
                }
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .accessibilityLabel("Выбранная карта, \(card.title)")
        } else {
            Color.clear
                .frame(height: 220)
        }
    }

    private var selectedCard: WalletCard? {
        guard let id = flow.selectedCardID else { return nil }
        return store.card(id: id)
    }

    private func cardSwipe(cards: [WalletCard]) -> some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                if value.translation.width <= -40 {
                    flow.selectAdjacentCard(offset: 1, cards: cards)
                } else if value.translation.width >= 40 {
                    flow.selectAdjacentCard(offset: -1, cards: cards)
                }
                dragX = 0
            }
    }

    // MARK: - Состояния

    @ViewBuilder
    private var stageContent: some View {
        switch flow.stage {
        case .idle:
            EmptyView()

        case .awaitingDoublePress(let isRetry):
            DoublePressHintView(
                text: isRetry ? "Повторите" : "Дважды нажмите кнопку, чтобы оплатить"
            )

        case .faceID:
            VStack(spacing: 22) {
                FaceIDGlyphView()
                Text("Подтвердите лицом")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
            }
            .accessibilityElement(children: .combine)

        case .holdNearReader:
            VStack(spacing: 16) {
                NFCWaveView()
                Text("Приложите iPhone к считывателю")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Наклоните устройство к считывателю")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "636368"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .accessibilityElement(children: .combine)

        case .success:
            VStack(spacing: 18) {
                SuccessCheckView()
                Text("Готово")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .accessibilityElement(children: .combine)

        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "FF453A"))
                Text(message)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Управление

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .global)
            .onEnded { value in
                if value.translation.height > 70, abs(value.translation.width) < 70 {
                    cancel()
                }
            }
    }

    private func startFlow() {
        guard !store.cards.isEmpty else {
            onDismiss()
            return
        }
        let resolvedID = cardID.flatMap { store.card(id: $0)?.id }
        flow.onFinished = {
            onDismiss()
        }
        flow.start(
            cardID: resolvedID,
            cards: store.cards,
            store: store,
            settings: settings.current
        )
    }

    private func cancel() {
        flow.stop()
        onDismiss()
    }

    private func closeAfterSuccess() {
        flow.stop()
        onDismiss()
    }
}
