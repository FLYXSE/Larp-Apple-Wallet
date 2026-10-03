import SwiftUI
import UIKit

private struct DetailScrollTopKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CardDetailView: View {
    let cardID: UUID
    let onClose: () -> Void
    let onEdit: () -> Void
    let onPay: () -> Void

    @EnvironmentObject private var store: WalletStore

    @State private var dragOffset: CGFloat = 0
    @State private var scrollTop: CGFloat = 0
    @State private var showAllTransactions = false

    private var card: WalletCard? {
        store.card(id: cardID)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let card = card {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        CardFace(card: card)
                            .offset(y: max(0, dragOffset))
                            .simultaneousGesture(dragToCollapse)
                            .padding(.top, 4)

                        titleBlock(card: card)
                        transactionsBlock(card: card)

                        toolbarView
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DetailScrollTopKey.self,
                                value: geo.frame(in: .named("detailScroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "detailScroll")
                .onPreferenceChange(DetailScrollTopKey.self) { value in
                    scrollTop = value
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            dragOffset = 0
            scrollTop = 0
            showAllTransactions = false
        }
        .onChange(of: store.cards) { _ in
            if card == nil {
                onClose()
            }
        }
    }

    // MARK: - Верхняя панель

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "1C1C1E"))
                    .clipShape(Circle())
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Свернуть карту")

            Spacer(minLength: 0)

            Button(action: onEdit) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "1C1C1E"))
                    .clipShape(Circle())
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Редактировать карту")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Заголовок и баланс

    private func titleBlock(card: WalletCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.title)
                .font(.system(size: 23, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            if let balance = card.balance {
                VStack(alignment: .leading, spacing: 4) {
                    Text("БАЛАНС")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.7)
                        .foregroundColor(Color(hex: "A0A0A5"))
                    Text(balance.moneyString())
                        .font(.system(size: 40, weight: .bold).monospacedDigit())
                        .foregroundColor(.white)
                }
            } else {
                Text(card.type.title.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.7)
                    .foregroundColor(Color(hex: "A0A0A5"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Операции

    private func transactionsBlock(card: WalletCard) -> some View {
        let transactions = card.transactions
        let visible = showAllTransactions ? transactions : Array(transactions.prefix(5))

        return VStack(alignment: .leading, spacing: 0) {
            Text("ПОСЛЕДНИЕ ОПЕРАЦИИ")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.7)
                .foregroundColor(Color(hex: "A0A0A5"))
                .padding(.bottom, 4)

            if transactions.isEmpty {
                Text("Операций пока нет")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "636368"))
                    .padding(.vertical, 14)
            } else {
                ForEach(visible) { transaction in
                    TransactionRow(transaction: transaction)
                    if transaction.id != visible.last?.id {
                        rowDivider
                    }
                }

                if transactions.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllTransactions.toggle()
                        }
                    } label: {
                        Text(showAllTransactions ? "Свернуть" : "Показать все")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "0A84FF"))
                            .padding(.vertical, 12)
                    }
                    .accessibilityLabel(showAllTransactions ? "Свернуть список операций" : "Показать все операции")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(hex: "262629"))
            .frame(height: 0.5)
            .padding(.leading, 44)
    }

    // MARK: - Нижний тулбар

    private var toolbarView: some View {
        HStack(spacing: 0) {
            toolbarButton("creditcard.fill", label: "Оплатить") {
                onPay()
            }
            Spacer(minLength: 0)
            toolbarButton("list.bullet.rectangle", label: "Операции") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAllTransactions.toggle()
                }
            }
            Spacer(minLength: 0)
            toolbarButton("ellipsis", label: "Ещё") {
                onEdit()
            }
        }
        .frame(height: 56)
        .background(LinearGradient(
            colors: [Color.white.opacity(0.14), Color.white.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
        ))
        .background(.regularMaterial)
        .clipShape(Capsule())
    }

    private func toolbarButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }

    // MARK: - Свайп вниз для свёртывания

    private var dragToCollapse: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                // Реагируем только когда контент прижат к верху — не мешаем скроллу.
                guard scrollTop >= -2, value.translation.height > 0 else { return }
                let translation = value.translation.height
                if translation > 100 {
                    dragOffset = 50 + (translation - 100) * 0.2
                } else {
                    dragOffset = translation * 0.5
                }
            }
            .onEnded { value in
                guard scrollTop >= -2 else { return }
                if value.translation.height > 60 {
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

// MARK: - Строка операции

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "2C2C2E"))
                    .frame(width: 32, height: 32)
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "A0A0A5"))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("− " + transaction.amount.moneyString())
                .font(.system(size: 17).monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(height: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(transaction.merchant), \(transaction.amount.moneyString()), \(transaction.date.formatted(date: .abbreviated, time: .shortened))"
        )
    }

    private var symbolName: String {
        UIImage(systemName: transaction.category) != nil ? transaction.category : "cart.fill"
    }
}
