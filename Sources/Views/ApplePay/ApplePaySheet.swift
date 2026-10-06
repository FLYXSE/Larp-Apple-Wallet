import SwiftUI

/// Полноэкранная симуляция оплаты в духе Apple Wallet / Apple Pay.
/// Верх: Cancel / заголовок / Add. Центр: карта + сумма.
/// Низ: панель Apple Pay (карта, смена метода, сумма, «Confirm with Side Button»).
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
                    header

                    Spacer(minLength: 8)

                    amountArea

                    Spacer(minLength: 0)

                    applePayPanel
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
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

    // MARK: - Верхняя панель

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("Отмена") {
                cancel()
            }
            .font(.system(size: 17))
            .foregroundColor(Color(hex: "0A84FF"))
            .accessibilityLabel("Отменить оплату")

            Spacer(minLength: 8)

            Text("Оплата")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 8)

            Text("Демо")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "0A84FF"))
                .frame(width: 44, alignment: .trailing)
                .accessibilityLabel("Демо-режим, реальная оплата не выполняется")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Карта + сумма

    private var amountArea: some View {
        VStack(spacing: 14) {
            if let card = selectedCard {
                miniCardFace(card: card)
                    .frame(width: 220)
                    .offset(x: dragX)
                    .simultaneousGesture(cardSwipe(cards: store.cards))
                    .onLongPressGesture(minimumDuration: 1.5) {
                        flow.handleFallbackHold()
                    }
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .accessibilityLabel("Выбранная карта, \(card.title)")
            } else {
                Color.clear
                    .frame(height: 140)
            }

            VStack(spacing: 6) {
                Text(settings.amount.moneyString())
                    .font(.system(size: 48, weight: .regular).monospacedDigit())
                    .foregroundColor(Color(hex: "8E8E93"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("Баланс: \(balanceText)")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "636368"))
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.25), value: flow.stage == .holdNearReader)
    }

    private var balanceText: String {
        if let card = selectedCard, let balance = card.balance {
            return balance.moneyString()
        }
        return "—"
    }

    /// Компактная карта как на скриншоте Apple Cash / платёжной шторки.
    private func miniCardFace(card: WalletCard) -> some View {
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

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.0), location: 0),
                    .init(color: .black.opacity(0.5), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    HStack(spacing: 4) {
                        if card.title.localizedCaseInsensitiveContains("cash") {
                            AppleMark(size: 14)
                        }
                        Text(card.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if let balance = card.balance {
                        Text(balance.moneyString())
                            .font(.system(size: 14, weight: .medium).monospacedDigit())
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        NetworkBadge(network: card.network)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 8)
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

    // MARK: - Нижняя панель Apple Pay

    private var applePayPanel: some View {
        VStack(spacing: 0) {
            HStack {
                ApplePayTitle()
                Spacer(minLength: 8)
                Button {
                    cancel()
                } label: {
                    AppIcon(name: .xmark, size: 18, lineWidth: 2.2, color: Color(hex: "8E8E93"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "2C2C2E"))
                        .clipShape(Circle())
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Закрыть Apple Pay")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if let card = selectedCard {
                paymentMethodRow(card: card)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            if flow.stage == .faceID {
                faceIDPanel
            } else {
                changeMethodRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                amountRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            Rectangle()
                .fill(Color(hex: "262629"))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            confirmRow
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "1C1C1E"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func paymentMethodRow(card: WalletCard) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: card.gradientColors.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 36)
                .overlay(alignment: .bottomLeading) {
                    if card.title.localizedCaseInsensitiveContains("cash") {
                        AppleMark(size: 10)
                            .padding(4)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle(for: card))
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(card.maskedNumber)
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(hex: "2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func subtitle(for card: WalletCard) -> String {
        if !card.displayHolder.isEmpty {
            return card.displayHolder
        }
        return card.type.title
    }

    private var changeMethodRow: some View {
        HStack {
            Text("Сменить способ оплаты")
                .font(.system(size: 17))
                .foregroundColor(.white)
            Spacer(minLength: 8)
            AppIcon(name: .chevronRight, size: 16, lineWidth: 2.2, color: Color(hex: "8E8E93"))
        }
        .padding(16)
        .background(Color(hex: "2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Сменить способ оплаты")
    }

    private var amountRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Сумма")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
                Text(settings.amount.moneyString())
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundColor(.white)
            }
            Spacer(minLength: 8)
            AppIcon(name: .chevronRight, size: 18, lineWidth: 2.2, color: Color(hex: "8E8E93"))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Сумма \(settings.amount.moneyString())")
    }

    // MARK: - Состояния панели

    @ViewBuilder
    private var faceIDPanel: some View {
        VStack(spacing: 14) {
            FaceIDGlyphView()
            Text("Подтвердите лицом")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Text("Системный Face ID")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Подтвердите лицом через Face ID")
    }

    @ViewBuilder
    private var confirmRow: some View {
        switch flow.stage {
        case .faceID:
            HStack(spacing: 12) {
                AppIcon(name: .faceID, size: 28, lineWidth: 2, color: Color(hex: "0A84FF"))
                Text("Ожидание Face ID")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8E8E93"))
                Spacer(minLength: 0)
            }

        case .holdNearReader:
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    AppIcon(name: .sideButton, size: 28, lineWidth: 2, color: Color(hex: "0A84FF"))
                    Text("Приложите к считывателю")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "0A84FF"))
                    Spacer(minLength: 0)
                }
                Text("Наклоните iPhone ≥ 25° и удерживайте")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "636368"))
            }

        case .success:
            HStack(spacing: 12) {
                AppIcon(name: .check, size: 26, lineWidth: 2.4, color: Color(hex: "30D158"))
                Text("Готово")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "FF453A"))
                Text("Повторите попытку")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "636368"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .idle, .awaitingDoublePress:
            HStack(spacing: 12) {
                AppIcon(name: .sideButton, size: 28, lineWidth: 2, color: Color(hex: "0A84FF"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Подтвердите боковой кнопкой")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "0A84FF"))
                    Text("Дважды нажмите справа от экрана")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "636368"))
                }
                Spacer(minLength: 0)
            }
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
