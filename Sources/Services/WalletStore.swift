import Combine
import Foundation

final class WalletStore: ObservableObject {
    @Published private(set) var cards: [WalletCard] = []

    let directory: URL
    private let cardsURL: URL

    init(directory: URL? = nil) {
        let base: URL
        if let directory = directory {
            base = directory
        } else {
            base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        self.directory = base
        self.cardsURL = base.appendingPathComponent("wallet.json")
        load()
    }

    // MARK: - Чтение

    func card(id: UUID) -> WalletCard? {
        cards.first { $0.id == id }
    }

    var topCard: WalletCard? {
        cards.first
    }

    // MARK: - Изменения

    func add(_ card: WalletCard) {
        cards.insert(card, at: 0)
        reindex()
        save()
    }

    func update(_ card: WalletCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.sortOrder = cards[index].sortOrder
        cards[index] = updated
        save()
    }

    func delete(id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let card = cards.remove(at: index)
        ImageStore.delete(relativePath: card.coverImagePath)
        reindex()
        save()
    }

    /// Сортировка + lastUsedAt обновляются при выборе карты для оплаты.
    func touch(cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        var card = cards.remove(at: index)
        card.lastUsedAt = Date()
        cards.insert(card, at: 0)
        reindex()
        save()
    }

    @discardableResult
    func recordPayment(cardID: UUID, merchant: String, amount: Decimal) -> Transaction? {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        let transaction = Transaction(
            merchant: merchant,
            amount: amount,
            date: Date(),
            category: "cart.fill"
        )
        var card = cards.remove(at: index)
        card.transactions.insert(transaction, at: 0)
        card.lastUsedAt = Date()
        cards.insert(card, at: 0)
        reindex()
        save()
        return transaction
    }

    // MARK: - Персистентность

    private func reindex() {
        for index in cards.indices {
            cards[index].sortOrder = index
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: cardsURL) else {
            cards = []
            return
        }
        do {
            let decoded = try JSONDecoder().decode([WalletCard].self, from: data)
            cards = decoded.sorted { $0.sortOrder < $1.sortOrder }
            reindex()
        } catch {
            // Повреждённый или несовместимый файл — пустой кошелёк вместо краша.
            cards = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(cards)
            try data.write(to: cardsURL, options: .atomic)
        } catch {
            // Локальная запись не удалась — данные остаются в памяти.
        }
    }
}
