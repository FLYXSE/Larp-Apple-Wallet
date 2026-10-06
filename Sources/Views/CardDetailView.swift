import SwiftUI
import UIKit

private struct DetailScrollTopKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Детали карты в духе Apple Cash: Done / …, карта, баланс + действие, операции.
struct CardDetailView: View {
    let cardID: UUID
    let onClose: () -> Void
    let onEdit: () -> Void
    let onPay: () -> Void

    @EnvironmentObject private var store: WalletStore

    @State private var dragOffset: CGFloat = 0
    @State private var scrollTop: CGFloat = 0
    @State private var showManageTransactions = false
    @State private var showSendOrRequest = false

    private var card: WalletCard? {
        store.card(id: cardID)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let card = card {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        CardFace(card: card)
                            .offset(y: max(0, dragOffset))
                            .simultaneousGesture(dragToCollapse)
                            .padding(.top, 4)

                        balanceCard(card: card)
                        transactionsHeader
                        transactionsList(card: card)

                        Color.clear.frame(height: 24)
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
        }
        .onChange(of: store.cards) { _ in
            if card == nil {
                onClose()
            }
        }
        .sheet(isPresented: $showManageTransactions) {
            if let card = card {
                ManageTransactionsView(cardID: card.id)
            }
        }
        .alert("Отправить или запросить", isPresented: $showSendOrRequest) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text("В демо-режиме переводы не выполняются.")
        }
    }

    // MARK: - Верхняя панель

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Text("Готово")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Закрыть карту")

            Spacer(minLength: 0)

            Button(action: onEdit) {
                AppIcon(name: .ellipsis, size: 18, lineWidth: 2.2, color: .white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "2C2C2E"))
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

    // MARK: - Баланс

    private func balanceCard(card: WalletCard) -> some View {
        GlassSurface(cornerRadius: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Баланс")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Text(card.balance?.moneyString() ?? "—")
                        .font(.system(size: 28, weight: .semibold).monospacedDigit())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                Button {
                    showSendOrRequest = true
                } label: {
                    Text("Отправить или запросить")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .accessibilityLabel("Отправить или запросить")
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Операции

    private var transactionsHeader: some View {
        HStack {
            Text("Операции")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            Spacer(minLength: 8)
            Button {
                showManageTransactions = true
            } label: {
                AppIcon(name: .search, size: 20, lineWidth: 2, color: Color(hex: "A0A0A5"))
                    .frame(width: 36, height: 36)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Управлять операциями")
        }
    }

    private func transactionsList(card: WalletCard) -> some View {
        let transactions = card.transactions
        let visible = Array(transactions.prefix(6))

        return VStack(alignment: .leading, spacing: 0) {
            if transactions.isEmpty {
                Text("Операций пока нет")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "636368"))
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                GlassSurface(cornerRadius: 16) {
                    VStack(spacing: 0) {
                        ForEach(visible) { transaction in
                            TransactionRow(transaction: transaction)
                            if transaction.id != visible.last?.id {
                                rowDivider
                            }
                        }
                    }
                }

                if transactions.count > visible.count {
                    Button {
                        showManageTransactions = true
                    } label: {
                        Text("Все операции")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "0A84FF"))
                            .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Открыть все операции")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(hex: "262629"))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    // MARK: - Свайп вниз

    private var dragToCollapse: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
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

// MARK: - Строка операции (иконка-квадрат как на скриншоте)

struct TransactionRow: View {
    let transaction: Transaction
    var trailingText: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            iconTile

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(trailingText ?? transaction.amount.moneyString())
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            AppIcon(name: .chevronRight, size: 14, lineWidth: 2.2, color: Color(hex: "636368"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconTile: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(iconBackground)
            .frame(width: 36, height: 36)
            .overlay {
                AppIcon(name: iconName, size: 18, lineWidth: 2, color: .white)
            }
    }

    private var iconBackground: Color {
        if transaction.category.contains("person") || transaction.merchant.localizedCaseInsensitiveContains("iphone") {
            return Color(hex: "30D158")
        }
        return Color.black
    }

    private var iconName: AppIconName {
        if transaction.category.contains("person") || transaction.merchant.localizedCaseInsensitiveContains("iphone") {
            return .person
        }
        return .bank
    }

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: transaction.date)
    }

    private var accessibilityLabel: String {
        "\(transaction.merchant), \(transaction.amount.moneyString()), \(subtitle)"
    }
}
