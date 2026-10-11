import Foundation

/// MoneyStalker ledger rules
///
/// 1. Money is stored as Int64 minor units. Formatting is display-only.
/// 2. Balance = opening + income − expenses − transfers out + transfers in + principal in − principal out.
/// 3. A transfer is one record. It changes two balances and is excluded from income, expenses, budgets, and savings rate.
/// 4. Loan principal changes an account balance and is excluded from income, expenses, and budgets.
/// 5. Interest is ordinary income or an ordinary expense.
/// 6. Credit cards use the same signed balance. Negative means the amount owed. Net worth sums signed balances and does not subtract credit cards a second time.
/// 7. Different currencies are never added unless the user entered an exchange rate.
/// 8. A cross-currency transfer stores a source amount and a destination amount.
/// 9. Budgets sum expenses only, in the budget currency, including subcategories of the chosen category.
/// 10. Goal progress is the sum of contribution records. A funded transfer is not income.
/// 11. Debt outstanding = original principal − principal repayments. It is derived, not stored.
/// 12. Opening balance is the balance before recorded transactions.
/// 13. Archived accounts stay in net worth and are hidden from pickers.
/// 14. Edits and deletes change every total because totals are derived from records.

struct BalanceBreakdown: Equatable, Sendable {
    var openingMinor: Int64
    var incomeMinor: Int64
    var expenseMinor: Int64
    var transfersOutMinor: Int64
    var transfersInMinor: Int64
    var principalInMinor: Int64
    var principalOutMinor: Int64
    var balanceMinor: Int64
}

struct CashflowTotals: Equatable, Sendable {
    var incomeMinor: Int64
    var expenseMinor: Int64
    var currencyCode: String

    var netMinor: Int64 { incomeMinor - expenseMinor }

    var savingsRateBasisPoints: Int64? {
        guard incomeMinor > 0 else { return nil }
        return ((incomeMinor - expenseMinor) * 10_000) / incomeMinor
    }
}

struct CategoryTotal: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var amountMinor: Int64
    var currencyCode: String
}

struct CashflowBucket: Identifiable, Hashable, Sendable {
    var id: Date
    var label: String
    var incomeMinor: Int64
    var expenseMinor: Int64
    var netMinor: Int64 { incomeMinor - expenseMinor }
}

struct NetWorthPoint: Identifiable, Hashable, Sendable {
    var id: Date
    var date: Date
    var minor: Int64
    var currencyCode: String
}

struct NetWorthSummary: Equatable, Sendable {
    var totalsByCurrency: [String: Int64]
    var displayMinor: Int64?
    var displayCurrency: String?
    var missingRateCurrencies: [String]
}

enum LedgerCalculator {
    static func breakdown(for account: AccountSnapshot, transactions: [TransactionSnapshot]) -> BalanceBreakdown {
        var income: Int64 = 0
        var expense: Int64 = 0
        var transfersOut: Int64 = 0
        var transfersIn: Int64 = 0
        var principalIn: Int64 = 0
        var principalOut: Int64 = 0

        for transaction in transactions {
            switch transaction.type {
            case .income:
                if transaction.accountID == account.id { income += transaction.amountMinor }
            case .expense:
                if transaction.accountID == account.id { expense += transaction.amountMinor }
            case .transfer:
                if transaction.accountID == account.id { transfersOut += transaction.amountMinor }
                if transaction.counterAccountID == account.id { transfersIn += transaction.destinationAmountMinor }
            case .principal:
                if transaction.accountID == account.id {
                    if transaction.principalDirection == .inbound {
                        principalIn += transaction.amountMinor
                    } else {
                        principalOut += transaction.amountMinor
                    }
                }
            }
        }

        let balance = account.openingBalanceMinor + income - expense - transfersOut + transfersIn + principalIn - principalOut
        return BalanceBreakdown(
            openingMinor: account.openingBalanceMinor,
            incomeMinor: income,
            expenseMinor: expense,
            transfersOutMinor: transfersOut,
            transfersInMinor: transfersIn,
            principalInMinor: principalIn,
            principalOutMinor: principalOut,
            balanceMinor: balance
        )
    }

    static func balanceMinor(for account: AccountSnapshot, transactions: [TransactionSnapshot]) -> Int64 {
        breakdown(for: account, transactions: transactions).balanceMinor
    }

    static func cashflow(
        transactions: [TransactionSnapshot],
        window: DateWindow?,
        currencyCode: String,
        accountID: UUID? = nil
    ) -> CashflowTotals {
        var income: Int64 = 0
        var expense: Int64 = 0
        for transaction in transactions {
            if let window, !window.contains(transaction.date) { continue }
            if transaction.currencyCode != currencyCode { continue }
            if let accountID, transaction.accountID != accountID { continue }
            switch transaction.type {
            case .income: income += transaction.amountMinor
            case .expense: expense += transaction.amountMinor
            case .transfer, .principal: break
            }
        }
        return CashflowTotals(incomeMinor: income, expenseMinor: expense, currencyCode: currencyCode)
    }

    static func categoryTotals(
        transactions: [TransactionSnapshot],
        categories: [CategorySnapshot],
        kind: CategoryKind,
        window: DateWindow?,
        currencyCode: String,
        accountID: UUID? = nil,
        rollUpToParent: Bool
    ) -> [CategoryTotal] {
        let type: TransactionType = kind == .income ? .income : .expense
        var sums: [UUID: Int64] = [:]
        for transaction in transactions where transaction.type == type {
            if let window, !window.contains(transaction.date) { continue }
            if transaction.currencyCode != currencyCode { continue }
            if let accountID, transaction.accountID != accountID { continue }
            guard let effective = transaction.effectiveCategoryID else { continue }
            let bucketID = rollUpToParent ? topLevelID(effective, categories: categories) : effective
            sums[bucketID, default: 0] += transaction.amountMinor
        }
        return sums.map { id, amount in
            let category = categories.first { $0.id == id }
            return CategoryTotal(
                id: id,
                name: category?.name ?? "Uncategorized",
                icon: category?.icon ?? "questionmark.circle",
                colorHex: category?.colorHex ?? "5C6770",
                amountMinor: amount,
                currencyCode: currencyCode
            )
        }
        .sorted { $0.amountMinor > $1.amountMinor }
    }

    static func topLevelID(_ id: UUID, categories: [CategorySnapshot]) -> UUID {
        guard let category = categories.first(where: { $0.id == id }) else { return id }
        return category.parentID ?? category.id
    }

    static func buckets(
        transactions: [TransactionSnapshot],
        window: DateWindow,
        currencyCode: String,
        accountID: UUID?,
        calendar: Calendar
    ) -> [CashflowBucket] {
        let component = bucketComponent(for: window, calendar: calendar)
        var cursor = alignedStart(window.start, component: component, calendar: calendar)
        var results: [CashflowBucket] = []
        var safety = 0
        while cursor < window.end && safety < 400 {
            safety += 1
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            let slice = DateWindow(start: max(cursor, window.start), end: min(next, window.end))
            let totals = cashflow(transactions: transactions, window: slice, currencyCode: currencyCode, accountID: accountID)
            results.append(CashflowBucket(id: cursor, label: bucketLabel(cursor, component: component, calendar: calendar), incomeMinor: totals.incomeMinor, expenseMinor: totals.expenseMinor))
            cursor = next
        }
        return results
    }

    static func netWorth(
        accounts: [AccountSnapshot],
        transactions: [TransactionSnapshot],
        preferredCurrency: String,
        rates: [String: Decimal],
        includeArchived: Bool,
        asOf: Date? = nil
    ) -> NetWorthSummary {
        let included = accounts.filter { account in
            (includeArchived || !account.isArchived) && (asOf == nil || account.createdAt <= asOf!)
        }
        let applicable = asOf == nil ? transactions : transactions.filter { $0.date <= asOf! }
        var totals: [String: Int64] = [:]
        for account in included {
            let balance = balanceMinor(for: account, transactions: applicable)
            totals[account.currencyCode, default: 0] += balance
        }
        let currencies = totals.keys.sorted()
        if currencies.isEmpty {
            return NetWorthSummary(totalsByCurrency: [:], displayMinor: 0, displayCurrency: preferredCurrency, missingRateCurrencies: [])
        }
        if currencies.count == 1, let only = currencies.first {
            return NetWorthSummary(totalsByCurrency: totals, displayMinor: totals[only], displayCurrency: only, missingRateCurrencies: [])
        }
        var converted: Int64 = 0
        var missing: [String] = []
        for (code, minor) in totals {
            if let value = CurrencyConverter.convert(minor: minor, from: code, to: preferredCurrency, preferred: preferredCurrency, rates: rates) {
                converted += value
            } else {
                missing.append(code)
            }
        }
        missing.sort()
        if missing.isEmpty {
            return NetWorthSummary(totalsByCurrency: totals, displayMinor: converted, displayCurrency: preferredCurrency, missingRateCurrencies: [])
        }
        return NetWorthSummary(totalsByCurrency: totals, displayMinor: nil, displayCurrency: nil, missingRateCurrencies: missing)
    }

    static func netWorthSeries(
        accounts: [AccountSnapshot],
        transactions: [TransactionSnapshot],
        window: DateWindow,
        preferredCurrency: String,
        rates: [String: Decimal],
        calendar: Calendar
    ) -> [NetWorthPoint] {
        let active = accounts.filter { !$0.isArchived }
        guard !active.isEmpty else { return [] }
        let summary = netWorth(accounts: active, transactions: transactions, preferredCurrency: preferredCurrency, rates: rates, includeArchived: false)
        guard summary.displayCurrency != nil else { return [] }
        var cursor = calendar.dateInterval(of: .month, for: window.start)?.start ?? window.start
        var points: [NetWorthPoint] = []
        var safety = 0
        while cursor < window.end && safety < 240 {
            safety += 1
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            let pointDate = min(next.addingTimeInterval(-1), window.end.addingTimeInterval(-1))
            let pointSummary = netWorth(
                accounts: active,
                transactions: transactions,
                preferredCurrency: preferredCurrency,
                rates: rates,
                includeArchived: false,
                asOf: pointDate
            )
            if let minor = pointSummary.displayMinor, let code = pointSummary.displayCurrency {
                points.append(NetWorthPoint(id: cursor, date: cursor, minor: minor, currencyCode: code))
            }
            cursor = next
        }
        return points
    }

    private static func bucketComponent(for window: DateWindow, calendar: Calendar) -> Calendar.Component {
        let days = calendar.dateComponents([.day], from: window.start, to: window.end).day ?? 0
        if days <= 45 { return .day }
        if days <= 180 { return .weekOfYear }
        return .month
    }

    private static func alignedStart(_ date: Date, component: Calendar.Component, calendar: Calendar) -> Date {
        switch component {
        case .day:
            return calendar.startOfDay(for: date)
        case .weekOfYear:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        default:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private static func bucketLabel(_ date: Date, component: Calendar.Component, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        switch component {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
        case .weekOfYear:
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
        default:
            formatter.setLocalizedDateFormatFromTemplate("MMM")
        }
        return formatter.string(from: date)
    }
}
