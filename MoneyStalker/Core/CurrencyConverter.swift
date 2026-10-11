import Foundation

enum CurrencyConverter {
    /// `rates` maps a currency code to how many major units of `preferred` equal one major unit of that code.
    static func convert(minor: Int64, from: String, to: String, preferred: String, rates: [String: Decimal]) -> Int64? {
        if from == to { return minor }
        let fromScale = CurrencyCatalog.fractionDigits(for: from)
        let toScale = CurrencyCatalog.fractionDigits(for: to)
        let fromMajor = MoneyMath.major(fromMinor: minor, scale: fromScale)
        guard let preferredMajor = toPreferred(fromMajor, code: from, preferred: preferred, rates: rates) else { return nil }
        guard let targetMajor = fromPreferred(preferredMajor, code: to, preferred: preferred, rates: rates) else { return nil }
        return MoneyMath.minorUnits(from: targetMajor, scale: toScale)
    }

    static func parseRates(_ raw: [String: String]) -> [String: Decimal] {
        var result: [String: Decimal] = [:]
        for (code, text) in raw {
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            if let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), decimal > 0 {
                result[code.uppercased()] = decimal
            }
        }
        return result
    }

    private static func toPreferred(_ major: Decimal, code: String, preferred: String, rates: [String: Decimal]) -> Decimal? {
        if code == preferred { return major }
        guard let rate = rates[code] else { return nil }
        return major * rate
    }

    private static func fromPreferred(_ major: Decimal, code: String, preferred: String, rates: [String: Decimal]) -> Decimal? {
        if code == preferred { return major }
        guard let rate = rates[code], rate != 0 else { return nil }
        return major / rate
    }
}
