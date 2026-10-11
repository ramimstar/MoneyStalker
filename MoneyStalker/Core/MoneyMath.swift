import Foundation

/// Minor-unit money math. Totals never use binary floating point.
enum MoneyMath {
    static func minorUnits(from decimal: Decimal, scale: Int) -> Int64? {
        guard scale >= 0, scale <= 6 else { return nil }
        var scaled = decimal * decimalPow10(scale)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        let number = NSDecimalNumber(decimal: rounded)
        if number == NSDecimalNumber.notANumber { return nil }
        let comparatorMax = NSDecimalNumber(value: Int64.max)
        let comparatorMin = NSDecimalNumber(value: Int64.min)
        if number.compare(comparatorMax) == .orderedDescending || number.compare(comparatorMin) == .orderedAscending {
            return nil
        }
        return number.int64Value
    }

    static func major(fromMinor minor: Int64, scale: Int) -> Decimal {
        Decimal(minor) / decimalPow10(scale)
    }

    static func decimalPow10(_ scale: Int) -> Decimal {
        Decimal(sign: .plus, exponent: scale, significand: 1)
    }
}

enum MoneyText {
    static func string(minor: Int64, code: String, locale: Locale) -> String {
        let scale = CurrencyCatalog.fractionDigits(for: code)
        let major = MoneyMath.major(fromMinor: minor, scale: scale)
        let safeCode = code.count == 3 ? code.uppercased() : "USD"
        return major.formatted(.currency(code: safeCode).locale(locale))
    }

    static func plain(minor: Int64, code: String) -> String {
        let scale = CurrencyCatalog.fractionDigits(for: code)
        let major = MoneyMath.major(fromMinor: minor, scale: scale)
        return major.formatted(.number.precision(.fractionLength(scale)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }

    static func percent(basisPoints: Int64) -> String {
        let value = Decimal(basisPoints) / Decimal(100)
        let number = value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale.current))
        return number + "%"
    }
}

enum MoneyInput {
    static func sanitize(_ raw: String, locale: Locale) -> String {
        let separator = locale.decimalSeparator ?? "."
        var result = ""
        var usedSeparator = false
        for character in raw {
            if character.isNumber {
                result.append(character)
            } else if String(character) == separator, !usedSeparator {
                usedSeparator = true
                result.append(separator)
            }
        }
        return result
    }

    static func minorUnits(from text: String, currencyCode: String, locale: Locale) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != (locale.decimalSeparator ?? ".") else { return nil }
        let separator = locale.decimalSeparator ?? "."
        let normalized = trimmed.replacingOccurrences(of: separator, with: ".")
        guard let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return MoneyMath.minorUnits(from: decimal, scale: CurrencyCatalog.fractionDigits(for: currencyCode))
    }
}
