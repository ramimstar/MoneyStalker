import Foundation

/// Personal-wealth estimate used by Money Stalker. This is not a fatwa.
///
/// The asset list and the 2.5% rate follow the personal-charity pattern described
/// by Islamic Relief's Zakat FAQ (gold nisab 87.48 g, silver nisab 612.36 g,
/// cash, trade stock, and short-term debts). Zakat Foundation of America's
/// calculator also lists retirement value, investment real estate, and zakat
/// paid in advance; those are optional or applied only to the amount due here.
/// Saudi ZATCA business zakat is not used.
enum ZakatNisabMethod: String, Codable, CaseIterable, Identifiable {
    case gold
    case silver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gold: "Gold nisab"
        case .silver: "Silver nisab"
        }
    }
}

enum ZakatStatus: String, Codable, Equatable {
    case missingPrice
    case belowNisab
    case hawlRequired
    case due
}

struct ZakatInput: Equatable {
    var method: ZakatNisabMethod = .silver
    var hawlConfirmed = false
    var cashHomeMinor: Int64 = 0
    var bankMinor: Int64 = 0
    var investmentsMinor: Int64 = 0
    var moneyLentMinor: Int64 = 0
    var receivablesMinor: Int64 = 0
    var businessCashMinor: Int64 = 0
    var inventoryMinor: Int64 = 0
    var otherAssetsMinor: Int64 = 0
    var includeRetirement = false
    var retirementMinor: Int64 = 0
    var shortTermLiabilitiesMinor: Int64 = 0
    var paidInAdvanceMinor: Int64 = 0
    var goldGrams: Decimal = 0
    var goldKarat: Decimal = 24
    var goldPricePerGramMinor: Int64 = 0
    var silverGrams: Decimal = 0
    var silverFineness: Decimal = Decimal(string: "0.999") ?? 1
    var silverPricePerGramMinor: Int64 = 0

    static let goldNisabGrams = Decimal(string: "87.48")!
    static let silverNisabGrams = Decimal(string: "612.36")!
    static let engineVersion = 1
}

struct ZakatResult: Equatable {
    var cashAndBankMinor: Int64
    var goldValueMinor: Int64
    var silverValueMinor: Int64
    var retirementIncludedMinor: Int64
    var eligibleAssetsMinor: Int64
    var deductionsMinor: Int64
    var netWealthMinor: Int64
    var nisabMinor: Int64?
    var zakatDueMinor: Int64
    var remainingMinor: Int64
    var status: ZakatStatus
    var notes: [String]
}

enum ZakatEngine {
    static func calculate(_ input: ZakatInput) -> ZakatResult {
        var notes: [String] = []
        let cashAndBank = nonNegative(input.cashHomeMinor) + nonNegative(input.bankMinor)
        let gold = metalValue(grams: input.goldGrams, purity: input.goldKarat / 24, pricePerGramMinor: input.goldPricePerGramMinor)
        let silver = metalValue(grams: input.silverGrams, purity: input.silverFineness, pricePerGramMinor: input.silverPricePerGramMinor)
        if input.goldGrams > 0, input.goldPricePerGramMinor <= 0 {
            notes.append("Gold was left out of the total because its price per gram was not entered.")
        }
        if input.silverGrams > 0, input.silverPricePerGramMinor <= 0 {
            notes.append("Silver was left out of the total because its price per gram was not entered.")
        }
        let retirement = input.includeRetirement ? nonNegative(input.retirementMinor) : 0
        if input.retirementMinor > 0, !input.includeRetirement {
            notes.append("Retirement savings stay out unless you turn that choice on. Pension rulings differ.")
        }
        let other = nonNegative(input.investmentsMinor)
            + nonNegative(input.moneyLentMinor)
            + nonNegative(input.receivablesMinor)
            + nonNegative(input.businessCashMinor)
            + nonNegative(input.inventoryMinor)
            + nonNegative(input.otherAssetsMinor)
        let eligible = cashAndBank + gold + silver + retirement + other
        let deductions = nonNegative(input.shortTermLiabilitiesMinor)
        let net = max(0, eligible - deductions)
        if deductions > eligible {
            notes.append("Short-term liabilities are higher than the entered assets, so net eligible wealth is zero.")
        }

        let nisabPrice = input.method == .gold ? input.goldPricePerGramMinor : input.silverPricePerGramMinor
        let nisabGrams = input.method == .gold ? ZakatInput.goldNisabGrams : ZakatInput.silverNisabGrams
        let nisab = nisabPrice > 0 ? metalValue(grams: nisabGrams, purity: 1, pricePerGramMinor: nisabPrice) : nil
        if nisab == nil {
            notes.append("Enter a manual \(input.method == .gold ? "gold" : "silver") price per gram before this method can compare wealth with nisab. No live price is used.")
            return ZakatResult(
                cashAndBankMinor: cashAndBank,
                goldValueMinor: gold,
                silverValueMinor: silver,
                retirementIncludedMinor: retirement,
                eligibleAssetsMinor: eligible,
                deductionsMinor: deductions,
                netWealthMinor: net,
                nisabMinor: nil,
                zakatDueMinor: 0,
                remainingMinor: 0,
                status: .missingPrice,
                notes: notes
            )
        }

        let meets = net >= (nisab ?? 0)
        if !meets {
            notes.append("Net eligible wealth is below the selected nisab, so this method does not estimate zakat as due.")
            return result(cashAndBank, gold, silver, retirement, eligible, deductions, net, nisab, 0, .belowNisab, notes, paid: input.paidInAdvanceMinor)
        }
        if !input.hawlConfirmed {
            notes.append("Wealth meets the selected nisab, but zakat is not estimated as due until you confirm that the hawl condition for this method is met.")
            return result(cashAndBank, gold, silver, retirement, eligible, deductions, net, nisab, 0, .hawlRequired, notes, paid: input.paidInAdvanceMinor)
        }
        let due = percent(net, numerator: 25, denominator: 1000)
        notes.append("The 2.5% rate is applied to net eligible wealth because the selected nisab is met and you confirmed hawl. It is not applied to wealth below nisab, and it is not a ruling for crops or livestock.")
        notes.append("This method follows the Islamic Relief explanation that a dip below nisab during the year does not, by itself, cancel zakat when wealth is above nisab on the seed date. Other opinions differ.")
        return result(cashAndBank, gold, silver, retirement, eligible, deductions, net, nisab, due, .due, notes, paid: input.paidInAdvanceMinor)
    }

    private static func result(
        _ cashAndBank: Int64,
        _ gold: Int64,
        _ silver: Int64,
        _ retirement: Int64,
        _ eligible: Int64,
        _ deductions: Int64,
        _ net: Int64,
        _ nisab: Int64?,
        _ due: Int64,
        _ status: ZakatStatus,
        _ notes: [String],
        paid: Int64
    ) -> ZakatResult {
        let advance = nonNegative(paid)
        let remaining = max(0, due - advance)
        var lines = notes
        if advance > 0 {
            lines.append("Zakat you marked as already paid reduces the remaining amount. It is not removed from the wealth total.")
        }
        return ZakatResult(
            cashAndBankMinor: cashAndBank,
            goldValueMinor: gold,
            silverValueMinor: silver,
            retirementIncludedMinor: retirement,
            eligibleAssetsMinor: eligible,
            deductionsMinor: deductions,
            netWealthMinor: net,
            nisabMinor: nisab,
            zakatDueMinor: due,
            remainingMinor: remaining,
            status: status,
            notes: lines
        )
    }

    static func metalValue(grams: Decimal, purity: Decimal, pricePerGramMinor: Int64) -> Int64 {
        guard grams > 0, pricePerGramMinor > 0, purity > 0 else { return 0 }
        let pure = grams * min(purity, 1)
        let value = pure * Decimal(pricePerGramMinor)
        return MoneyMath.minorUnits(from: value, scale: 0) ?? 0
    }

    static func percent(_ minor: Int64, numerator: Int64, denominator: Int64) -> Int64 {
        guard minor > 0, denominator > 0 else { return 0 }
        let value = (Decimal(minor) * Decimal(numerator)) / Decimal(denominator)
        return MoneyMath.minorUnits(from: value, scale: 0) ?? 0
    }

    static func nonNegative(_ value: Int64) -> Int64 { max(0, value) }

    static func decimal(from text: String, locale: Locale) -> Decimal {
        let separator = locale.decimalSeparator ?? "."
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: separator, with: ".")
        guard !normalized.isEmpty else { return 0 }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}

enum CharityMath {
    static func canLink(transactionID: UUID, existingTransactionIDs: [UUID]) -> Bool {
        !existingTransactionIDs.contains(transactionID)
    }

    static func remainingAfterPayments(snapshotRemainingMinor: Int64, laterPaymentsMinor: Int64) -> Int64 {
        max(0, snapshotRemainingMinor - max(0, laterPaymentsMinor))
    }

    static func progress(amounts: [(date: Date, amountMinor: Int64, currencyCode: String)], currencyCode: String, start: Date, end: Date?) -> Int64 {
        amounts.reduce(0) { partial, item in
            guard item.currencyCode == currencyCode, item.date >= start else { return partial }
            if let end, item.date > end { return partial }
            return partial + max(0, item.amountMinor)
        }
    }
}

enum RamadanMath {
    static func contains(_ date: Date, start: Date, end: Date) -> Bool {
        date >= start && date <= end
    }

    static func spent(lineID: UUID, links: [(lineID: UUID, transactionID: UUID)], amounts: [UUID: Int64]) -> Int64 {
        var seen = Set<UUID>()
        var total: Int64 = 0
        for link in links where link.lineID == lineID {
            guard seen.insert(link.transactionID).inserted else { continue }
            total += max(0, amounts[link.transactionID] ?? 0)
        }
        return total
    }

    static func warns(plannedMinor: Int64, actualMinor: Int64) -> Bool {
        plannedMinor > 0 && actualMinor > plannedMinor
    }
}
