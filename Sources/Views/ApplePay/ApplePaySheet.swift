import SwiftUI
import UIKit

/// Шторка оплаты в духе скриншотов Apple Pay:
/// светлая/системная тема, крупная карта сверху в цвете карты,
/// в центре Face ID / «Поднесите к считывателю», снизу — стопка карт.
/// Без баннеров «Демонстрация» и без суммы на экране оплаты.
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
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                if flow.stage == .success {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeAfterSuccess)
                }

                VStack(spacing: 0) {
                    // Карта крупно вверху — цвет/фото из настроек карты.
                    if let card = selectedCard {
                        payCardFace(card: card)
                            .frame(maxWidth: 300)
                            .padding(.top, 12)
                            .offset(x: dragX)
                            .simultaneousGesture(cardSwipe(cards: store.cards))
                            .onLongPressGesture(minimumDuration: 1.5) {
                                flow.handleFallbackHold()
                            }
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                            .accessibilityLabel("Выбранная карта, \(card.title)")
                    } else {
                        Color.clear.frame(height: 180)
                    }

                    Spacer(minLength: 12)

                    stageCenter
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 12)

                    // Стопка карт снизу, как на скриншоте Apple Pay.
                    bottomCardPeek
                        .frame(height: 90)
                        .clipped()
                }

                // Реплика боковой кнопки справа (двойное нажатие).
                if case .awaitingDoublePress = flow.stage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 10) {
                                Text("Дважды нажмите\nдля оплаты")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)

                                SideButtonReplica(isEnabled: true) {
                                    flow.handleDoublePress()
                                }
                            }
                        }
                        .padding(.trailing, 18)
                        .padding(.bottom, geo.size.height * 0.38)
                    }
                }

                // Закрыть — тонкая кнопка в углу, без большого баннера.
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            cancel()
                        } label: {
                            Text("Закрыть")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "0A84FF"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: "0A84FF").opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel("Закрыть оплату")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear(perform: startFlow)
        .onDisappear {
            flow.stop()
        }
        .simultaneousGesture(dismissGesture)
        .animation(.easeInOut(duration: 0.28), value: flow.stage)
        // Тема оплаты — как на iPhone (система/светлая/тёмная).
        .preferredColorScheme(settings.colorScheme)
    }

    // MARK: - Крупная карта (цвет или фото из настроек)

    private func payCardFace(card: WalletCard) -> some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let path = card.coverImagePath, let image = ImageStore.load(relativePath: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: card.gradientColors.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }

            // Лёгкий скрим для читаемости — только снизу, не «зелёный» фильтр.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.18), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    if card.title.localizedCaseInsensitiveContains("cash") {
                        AppleMark(size: 16)
                    } else {
                        Text(card.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    }
                    Spacer(minLength: 6)
                    NetworkBadge(network: card.network)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    Text(card.maskedNumber)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    Spacer(minLength: 8)
                    if !card.displayHolder.isEmpty {
                        Text(card.displayHolder)
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.6)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color(hex: card.gradientColors.first ?? "000000").opacity(0.35), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
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

    // MARK: - Центр: стадии без суммы

    @ViewBuilder
    private var stageCenter: some View {
        switch flow.stage {
        case .faceID:
            VStack(spacing: 18) {
                Image(systemName: "faceid")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundColor(Color(hex: "0A84FF"))
                    .frame(width: 72, height: 72)

                Text("Face ID")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Подтвердите лицом через Face ID")

        case .holdNearReader:
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "0A84FF"), lineWidth: 3)
                        .frame(width: 72, height: 72)

                    Image(systemName: "iphone")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundColor(Color(hex: "0A84FF"))
                }

                Text("Поднесите к\nсчитывателю")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Поднесите устройство к считывателю")

        case .success:
            VStack(spacing: 18) {
                SuccessCheckView()
                Text("Готово")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Оплата прошла успешно")

        case .failed(let message):
            VStack(spacing: 8) {
                AppIcon(name: .faceID, size: 48, color: Color(hex: "FF453A"))
                Text(message)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: "FF453A"))
                    .multilineTextAlignment(.center)
                Text("Повторите попытку")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

        case .idle, .awaitingDoublePress:
            VStack(spacing: 16) {
                AppIcon(name: .sideButton, size: 40, color: Color(hex: "0A84FF"))
                Text("Подтвердите боковой кнопкой")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                Text("Дважды нажмите справа от экрана")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "AEAEB2"))
            }
        }
    }

    // MARK: - Стопка карт снизу

    private var bottomCardPeek: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .top) {
                ForEach(Array(store.cards.prefix(4).enumerated()), id: \.element.id) { index, card in
                    Rectangle()
                        .fill(
                            Group {
                                if let path = card.coverImagePath, let image = ImageStore.load(relativePath: path) {
                                    Image(uiImage: image)
                                } else {
                                    LinearGradient(
                                        colors: card.gradientColors.map { Color(hex: $0) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .frame(width: 220, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .offset(y: CGFloat(index) * 10)
                        .opacity(index == 0 ? 0.35 : 0.55)
                        .zIndex(Double(store.cards.count - index))
                }
            }
            .frame(width: 220, height: 70)
        }
        .padding(.bottom, 8)
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
