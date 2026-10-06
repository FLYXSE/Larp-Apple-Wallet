import SwiftUI
import UIKit

/// Управление операциями карты — в духе «Manage Transactions».
struct ManageTransactionsView: View {
    let cardID: UUID

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var editMode = false
    @State private var showAdd = false

    private var card: WalletCard? {
        store.card(id: cardID)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Операции")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    Text("СВОИ")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)

                    transactionCard
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .alert("Добавить операцию", isPresented: $showAdd) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text("В демо-режиме новые операции не сохраняются.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button("Готово") {
                dismiss()
            }
            .font(.system(size: 17))
            .foregroundColor(Color(hex: "0A84FF"))

            Spacer(minLength: 8)

            Button("Добавить") {
                showAdd = true
            }
            .font(.system(size: 17))
            .foregroundColor(Color(hex: "0A84FF"))

            Spacer(minLength: 8)

            Button(editMode ? "Готово" : "Изменить") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    editMode.toggle()
                }
            }
            .font(.system(size: 17))
            .foregroundColor(Color(hex: "0A84FF"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var transactionCard: some View {
        if let card = card, !card.transactions.isEmpty {
            VStack(spacing: 0) {
                ForEach(card.transactions) { transaction in
                    HStack(spacing: 12) {
                        TransactionRow(
                            transaction: transaction,
                            trailingText: "+" + transaction.amount.moneyString()
                        )

                        if editMode {
                            Button("Изменить") {}
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "0A84FF"))
                        }
                    }
                    .padding(.trailing, editMode ? 12 : 0)

                    if transaction.id != card.transactions.last?.id {
                        Rectangle()
                            .fill(Color.primary.opacity(0.10))
                            .frame(height: 0.5)
                            .padding(.leading, 56)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
        } else {
            Text("Операций пока нет")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
        }
    }
}
