import SwiftUI

struct WalletHome: View {
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var expandedCardID: UUID?
    @State private var editingCard: WalletCard?
    @State private var payCardID: UUID?
    @State private var showPaySheet = false
    @State private var showAddCard = false
    @State private var showSettings = false
    @State private var showNoCardAlert = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if store.cards.isEmpty {
                    emptyState
                } else {
                    CardStackView(
                        cards: store.cards,
                        onSelect: expand,
                        onEdit: { card in
                            editingCard = card
                        }
                    )
                    .opacity(expandedCardID == nil ? 1 : 0)
                    .offset(y: expandedCardID == nil ? 0 : 480)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: expandedCardID)

            if let cardID = expandedCardID {
                CardDetailView(
                    cardID: cardID,
                    onClose: collapse,
                    onEdit: {
                        if let card = store.card(id: cardID) {
                            editingCard = card
                        }
                    },
                    onPay: {
                        startPay(cardID: cardID)
                    }
                )
                .transition(.opacity)
                .zIndex(2)
            }

            if showPaySheet {
                ApplePaySheet(
                    cardID: payCardID,
                    onDismiss: dismissPay
                )
                .transition(.opacity)
                .zIndex(3)
            }

            if expandedCardID == nil && !showPaySheet {
                PayButton(action: startPayFromStack)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 24)
                    .padding(.bottom, 10)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .sheet(isPresented: $showAddCard) {
            AddCardSheet()
        }
        .sheet(item: $editingCard) { card in
            EditCardSheet(card: card)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .alert("Добавьте карту, чтобы оплатить", isPresented: $showNoCardAlert) {
            Button("ОК", role: .cancel) {}
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Кошелёк")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)

            Spacer(minLength: 8)

            Button {
                showAddCard = true
                Haptics.selection()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.5) {
                showSettings = true
                Haptics.selection()
            }
            .accessibilityLabel("Добавить карту")
            .accessibilityHint("Долгое нажатие открывает настройки")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Пустое состояние

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color(hex: "636368"),
                        style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                    )
                    .frame(width: 220, height: 140)

                Image(systemName: "creditcard")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundColor(Color(hex: "636368"))
            }

            Text("Нажмите +, чтобы добавить карту")
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "A0A0A5"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Действия

    private func expand(_ card: WalletCard) {
        Haptics.impact(.medium)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            expandedCardID = card.id
        }
    }

    private func collapse() {
        Haptics.impact(.soft)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            expandedCardID = nil
        }
    }

    private func startPayFromStack() {
        guard let card = store.topCard else {
            showNoCardAlert = true
            return
        }
        startPay(cardID: card.id)
    }

    private func startPay(cardID: UUID) {
        payCardID = cardID
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showPaySheet = true
        }
    }

    private func dismissPay() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showPaySheet = false
        }
    }
}
