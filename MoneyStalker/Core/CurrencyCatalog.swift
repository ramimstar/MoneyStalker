import Foundation

struct CurrencyInfo: Identifiable, Hashable, Sendable {
    var id: String { code }
    var code: String
    var name: String
    var fractionDigits: Int
}

enum CurrencyCatalog {
    static let common: [CurrencyInfo] = [
        .init(code: "BDT", name: "Bangladeshi Taka", fractionDigits: 2),
        .init(code: "USD", name: "US Dollar", fractionDigits: 2),
        .init(code: "EUR", name: "Euro", fractionDigits: 2),
        .init(code: "GBP", name: "British Pound", fractionDigits: 2),
        .init(code: "INR", name: "Indian Rupee", fractionDigits: 2),
        .init(code: "JPY", name: "Japanese Yen", fractionDigits: 0),
        .init(code: "CAD", name: "Canadian Dollar", fractionDigits: 2),
        .init(code: "AUD", name: "Australian Dollar", fractionDigits: 2),
        .init(code: "SGD", name: "Singapore Dollar", fractionDigits: 2),
        .init(code: "AED", name: "UAE Dirham", fractionDigits: 2),
        .init(code: "SAR", name: "Saudi Riyal", fractionDigits: 2),
        .init(code: "CNY", name: "Chinese Yuan", fractionDigits: 2),
        .init(code: "CHF", name: "Swiss Franc", fractionDigits: 2),
        .init(code: "KRW", name: "South Korean Won", fractionDigits: 0),
        .init(code: "KWD", name: "Kuwaiti Dinar", fractionDigits: 3),
        .init(code: "BHD", name: "Bahraini Dinar", fractionDigits: 3)
    ]

    static func fractionDigits(for code: String) -> Int {
        common.first { $0.code == code.uppercased() }?.fractionDigits ?? 2
    }

    static func isKnownISOCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 3, trimmed.allSatisfy({ $0.isLetter }) else { return false }
        return true
    }
}
