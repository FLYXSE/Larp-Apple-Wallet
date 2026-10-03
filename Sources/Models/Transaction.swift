import Foundation

struct Transaction: Codable, Identifiable, Equatable {
    let id: UUID
    var merchant: String
    var amount: Decimal
    var date: Date
    var category: String

    init(
        id: UUID = UUID(),
        merchant: String,
        amount: Decimal,
        date: Date = Date(),
        category: String = "cart.fill"
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.category = category
    }
}

extension Decimal {
    func moneyString(currency: String = "₽") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let value = NSDecimalNumber(decimal: self)
        let number = formatter.string(from: value) ?? "\(value)"
        return number + " " + currency
    }
}
