import SwiftUI

/// Полноэкранная симуляция оплаты под скриншот Apple Pay (Liquid Glass).
/// Верх: синий баннер «Демонстрация Apple Pay» + кнопка «Завершить».
/// Центр: карта (как Apple Cash на демо).
/// Низ: иконка iPhone + «Поднесите устройство к считывателю»
/// и стеклянная плашка с подсказкой (Liquid Glass).
struct ApplePaySheet: View {
    let cardID: UUID?
    let onDismiss: () -> Void

    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var settings: SettingsStore

    @StateObject private var flow = PaymentFlowController()
    @State private var dragX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                if flow.stage == .success {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeAfterSuccess)
                }

                VStack(spacing: 0) {
                    headerBanner

                    Spacer(minLength: 8)

                    cardArea

                    Spacer(minLength: 0)

                    paymentPrompt
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    glassTip
                        .padding(.horizontal, 20)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 10 : 22)
                }
                .padding(.top, 8)

                if case .awaitingDoublePress = flow.stage {
                    VStack(spacing: 10) {
                        Spacer()
                        HStack(alignment: .center, spacing: 14) {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 10) {
                                Text("Дважды нажмите\nдля оплаты")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)

                                SideButtonReplica(isEnabled: true) {
                                    flow.handleDoublePress()
                                }
                            }
                        }
                        .padding(.trailing, 18)
                        .padding(.bottom, geo.size.height * 0.42)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: startFlow)
        .onDisappear {
            flow.stop()
        }
        .simultaneousGesture(dismissGesture)
        .animation(.easeInOut(duration: 0.3), value: flow.stage)
        .preferredColorScheme(.dark)
    }

    // MARK: - Верхний синий баннер

    private var headerBanner: some View {
        GlassSurface(cornerRadius: 22, tint: Color(hex: "0A84FF").opacity(0.28)) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Демонстрация Apple Pay")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Средства не будут списаны с Вашей карты")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    cancel()
                } label: {
                    Text("Завершить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .contentShape(Rectangle())
                .accessibilityLabel("Завершить демо-оплату")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Карта

    private var cardArea: some View {
        VStack(spacing: 14) {
            if let card = selectedCard {
                payCardFace(card: card)
                    .frame(width: 250)
                    .offset(x: dragX)
                    .simultaneousGesture(cardSwipe(cards: store.cards))
                    .onLongPressGesture(minimumDuration: 1.5) {
                        flow.handleFallbackHold()
                    }
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .accessibilityLabel("Выбранная карта, \(card.title)")

                if let balance = selectedCard?.balance {
                    Text(balance.moneyString())
                        .font(.system(size: 22, weight: .semibold).monospacedDigit())
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            } else {
                Color.clear
                    .frame(height: 160)
            }
        }
        .padding(.horizontal, 24)
    }

    private var selectedCard: WalletCard? {
        guard let id = flow.selectedCardID else { return nil }
        return store.card(id: id)
    }

    private func payCardFace(card: WalletCard) -> some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let path = card.coverImagePath, let image = ImageStore.load(relativePath: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Зелёная Apple Cash-подобная карта — как на скриншоте демо.
                    LinearGradient(
                        colors: [
                            Color(hex: "5BC878"),
                            Color(hex: "30B857"),
                            Color(hex: "238E43")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.05), location: 0),
                    .init(color: .black.opacity(0.28), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    HStack(spacing: 4) {
                        AppleMark(size: 15)
                        Text(card.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if let balance = card.balance {
                        Text(balance.moneyString())
                            .font(.system(size: 14, weight: .medium).monospacedDigit())
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                    } else {
                        NetworkBadge(network: card.network)
                    }
                }
                Spacer(minLength: 0)
                Text("Apple Cash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(14)
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color(hex: "30B857").opacity(0.45), radius: 22, x: 0, y: 12)
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
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

    // MARK: - Призыв «поднесите к считывателю»

    @ViewBuilder
    private var paymentPrompt: some View {
        switch flow.stage {
        case .faceID:
            GlassSurface(cornerRadius: 24) {
                VStack(spacing: 14) {
                    FaceIDGlyphView()
                    Text("Подтвердите лицом")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Системный Face ID (LAContext)")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 16)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Подтвердите лицом через системный Face ID")

        case .holdNearReader:
            VStack(spacing: 16) {
                NFCWaveView()
                Text("Поднесите устройство\nк считывателю")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Поднесите устройство к считывателю")

        case .success:
            VStack(spacing: 14) {
                SuccessCheckView()
                Text("Готово")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Оплата прошла успешно")

        case .failed(let message):
            GlassSurface(cornerRadius: 22, tint: Color(hex: "FF453A").opacity(0.22)) {
                VStack(spacing: 6) {
                    Text(message)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "FF453A"))
                    Text("Повторите попытку")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }

        case .idle, .awaitingDoublePress:
            VStack(spacing: 12) {
                AppIcon(name: .sideButton, size: 34, lineWidth: 2, color: Color(hex: "0A84FF"))
                Text("Подтвердите боковой кнопкой")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Дважды нажмите справа от экрана")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.6))
            }
        }
    }

    // MARK: - Стеклянная подсказка (Liquid Glass)

    private var glassTip: some View {
        GlassSurface(cornerRadius: 24, tint: Color.white.opacity(0.10)) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Проведите оплату с iPhone")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Наклоните iPhone и поднесите к терминалу для бесконтактной оплаты")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                ContactlessBadge()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Проведите оплату с iPhone. Наклоните iPhone и поднесите к терминалу для бесконтактной оплаты")
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
