import Foundation

struct WalletCard: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var type: CardType
    var number: String
    var expiry: String
    var holder: String
    var balance: Decimal?
    var coverImagePath: String?
    var gradient: [String]
    var network: CardNetwork
    var createdAt: Date
    var lastUsedAt: Date?
    var transactions: [Transaction]
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        type: CardType = .credit,
        number: String = "",
        expiry: String = "",
        holder: String = "",
        balance: Decimal? = nil,
        coverImagePath: String? = nil,
        gradient: [String] = WalletCard.defaultGradient,
        network: CardNetwork = .none,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        transactions: [Transaction] = [],
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.number = number
        self.expiry = expiry
        self.holder = holder
        self.balance = balance
        self.coverImagePath = coverImagePath
        self.gradient = gradient
        self.network = network
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.transactions = transactions
        self.sortOrder = sortOrder
    }

    static let defaultGradient = ["E8E8EB", "A8A8AD", "3D3D3F"]

    var digits: String {
        number.filter { $0.isNumber }
    }

    var maskedNumber: String {
        let last4 = String(digits.suffix(4))
        let tail = last4.isEmpty ? "••••" : last4
        return "•••• " + tail
    }

    var displayHolder: String {
        holder.uppercased()
    }

    var gradientColors: [String] {
        gradient.isEmpty ? WalletCard.defaultGradient : gradient
    }
}
