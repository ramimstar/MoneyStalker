import Foundation

enum CSVExporter {
    static func transactions(
        _ items: [TransactionSnapshot],
        accounts: [AccountSnapshot],
        categories: [CategorySnapshot]
    ) -> String {
        var rows = ["id,date,type,amount,currency,destination_amount,destination_currency,account,counter_account,category,subcategory,notes,tags,linkage"]
        let formatter = ISO8601DateFormatter()
        for item in items {
            let account = accounts.first { $0.id == item.accountID }?.name ?? ""
            let counter = accounts.first { $0.id == item.counterAccountID }?.name ?? ""
            let category = categories.first { $0.id == item.categoryID }?.name ?? ""
            let subcategory = categories.first { $0.id == item.subcategoryID }?.name ?? ""
            let fields = [
                item.id.uuidString,
                formatter.string(from: item.date),
                item.type.rawValue,
                MoneyText.plain(minor: item.amountMinor, code: item.currencyCode),
                item.currencyCode,
                MoneyText.plain(minor: item.destinationAmountMinor, code: item.destinationCurrencyCode),
                item.destinationCurrencyCode,
                account,
                counter,
                category,
                subcategory,
                item.notes,
                item.tags.joined(separator: "|"),
                item.linkage.rawValue
            ]
            rows.append(fields.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    static func summary(netWorth: NetWorthSummary, cashflow: CashflowTotals, locale: Locale) -> String {
        var lines = ["Money Stalker summary", "Currency totals are calculated from opening balances and recorded transactions."]
        if let minor = netWorth.displayMinor, let code = netWorth.displayCurrency {
            lines.append("Net worth: \(MoneyText.string(minor: minor, code: code, locale: locale))")
        } else if !netWorth.missingRateCurrencies.isEmpty {
            lines.append("Net worth is split because some currencies have no exchange rate: \(netWorth.missingRateCurrencies.joined(separator: ", ")).")
        }
        for (code, minor) in netWorth.totalsByCurrency.sorted(by: { $0.key < $1.key }) {
            lines.append("\(code): \(MoneyText.string(minor: minor, code: code, locale: locale))")
        }
        lines.append("Income: \(MoneyText.string(minor: cashflow.incomeMinor, code: cashflow.currencyCode, locale: locale))")
        lines.append("Expenses: \(MoneyText.string(minor: cashflow.expenseMinor, code: cashflow.currencyCode, locale: locale))")
        lines.append("Net: \(MoneyText.string(minor: cashflow.netMinor, code: cashflow.currencyCode, locale: locale))")
        if let rate = cashflow.savingsRateBasisPoints {
            lines.append("Savings rate: \(MoneyText.percent(basisPoints: rate))")
        } else {
            lines.append("Savings rate: not available because income is zero.")
        }
        return lines.joined(separator: "\n")
    }

    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
