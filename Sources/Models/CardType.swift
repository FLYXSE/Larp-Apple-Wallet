import CoreGraphics
import Foundation

enum CardType: String, Codable, CaseIterable, Identifiable {
    case credit
    case debit
    case transit
    case boarding
    case loyalty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .credit: return "Кредит"
        case .debit: return "Дебет"
        case .transit: return "Транспорт"
        case .boarding: return "Талон"
        case .loyalty: return "Лоялти"
        }
    }

    var cardHeight: CGFloat {
        switch self {
        case .credit, .debit, .transit: return 220
        case .boarding: return 280
        case .loyalty: return 200
        }
    }

    var symbol: String {
        switch self {
        case .credit: return "creditcard"
        case .debit: return "banknote"
        case .transit: return "tram.fill"
        case .boarding: return "airplane"
        case .loyalty: return "star.fill"
        }
    }
}

enum CardNetwork: String, Codable, CaseIterable, Identifiable {
    case visa
    case mastercard
    case amex
    case mir
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visa: return "VISA"
        case .mastercard: return "Mastercard"
        case .amex: return "AMEX"
        case .mir: return "МИР"
        case .none: return "Без платёжной сети"
        }
    }

    static func infer(from numberDigits: String, type: CardType) -> CardNetwork {
        switch type {
        case .transit, .boarding, .loyalty:
            return .none
        default:
            break
        }
        guard let first = numberDigits.first else { return .none }
        switch first {
        case "4": return .visa
        case "5": return .mastercard
        case "3": return .amex
        case "2": return .mir
        default: return .none
        }
    }
}
