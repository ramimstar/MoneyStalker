import Foundation

enum TransactionValidator {
    static func validate(_ draft: TransactionDraft, accounts: [AccountSnapshot], allowArchived: Bool) throws {
        guard draft.amountMinor > 0 else { throw TransactionDraftError.invalidAmount }
        guard draft.notes.count <= 2_000 else { throw TransactionDraftError.notesTooLong }
        guard draft.tags.count <= 12, draft.tags.allSatisfy({ !$0.isEmpty && $0.count <= 30 }) else {
            throw TransactionDraftError.invalidTag
        }
        guard let accountID = draft.accountID, let account = accounts.first(where: { $0.id == accountID }) else {
            throw TransactionDraftError.missingAccount
        }
        if account.isArchived && !allowArchived { throw TransactionDraftError.archivedAccount }

        switch draft.type {
        case .income, .expense:
            if draft.categoryID == nil { throw TransactionDraftError.missingCategory }
        case .transfer:
            guard let counterID = draft.counterAccountID, let counter = accounts.first(where: { $0.id == counterID }) else {
                throw TransactionDraftError.missingCounterAccount
            }
            if counter.isArchived && !allowArchived { throw TransactionDraftError.archivedAccount }
            if counter.id == account.id { throw TransactionDraftError.sameAccountTransfer }
            if account.currencyCode != counter.currencyCode {
                guard let destination = draft.destinationAmountMinor, destination > 0 else {
                    throw TransactionDraftError.destinationAmountRequired
                }
            }
        case .principal:
            break
        }
    }

    static func isLikelyDuplicate(_ draft: TransactionDraft, existing: [TransactionSnapshot], now: Date = .now) -> Bool {
        existing.contains { transaction in
            if transaction.id == draft.editingID { return false }
            guard transaction.type == draft.type,
                  transaction.amountMinor == draft.amountMinor,
                  transaction.accountID == draft.accountID,
                  transaction.categoryID == draft.categoryID,
                  transaction.notes == draft.notes else { return false }
            let dateGap = abs(transaction.date.timeIntervalSince(draft.date))
            let createdGap = abs(transaction.createdAt.timeIntervalSince(now))
            return dateGap < 60 && createdGap < 120
        }
    }
}

struct TransactionFilter: Equatable, Sendable {
    var type: TransactionType?
    var categoryID: UUID?
    var accountID: UUID?
    var minimumMinor: Int64?
    var maximumMinor: Int64?
    var tag: String?
    var window: DateWindow?
    var query: String = ""
    var sort: TransactionSort = .newest
    var grouping: TransactionGrouping = .day

    var activeCount: Int {
        var count = 0
        if type != nil { count += 1 }
        if categoryID != nil { count += 1 }
        if accountID != nil { count += 1 }
        if minimumMinor != nil || maximumMinor != nil { count += 1 }
        if let tag, !tag.isEmpty { count += 1 }
        if window != nil { count += 1 }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        return count
    }
}

enum TransactionQuery {
    static func apply(
        _ items: [TransactionSnapshot],
        filter: TransactionFilter,
        accounts: [AccountSnapshot],
        categories: [CategorySnapshot]
    ) -> [TransactionSnapshot] {
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items.filter { transaction in
            if let type = filter.type, transaction.type != type { return false }
            if let window = filter.window, !window.contains(transaction.date) { return false }
            if let categoryID = filter.categoryID,
               transaction.categoryID != categoryID,
               transaction.subcategoryID != categoryID,
               LedgerCalculator.topLevelID(transaction.effectiveCategoryID ?? UUID(), categories: categories) != categoryID {
                return false
            }
            if let accountID = filter.accountID, transaction.accountID != accountID, transaction.counterAccountID != accountID {
                return false
            }
            if let minimum = filter.minimumMinor, transaction.amountMinor < minimum { return false }
            if let maximum = filter.maximumMinor, transaction.amountMinor > maximum { return false }
            if let tag = filter.tag?.trimmingCharacters(in: .whitespacesAndNewlines), !tag.isEmpty {
                let needle = tag.lowercased()
                if !transaction.tags.contains(where: { $0.lowercased() == needle }) { return false }
            }
            if !query.isEmpty {
                let haystack = searchText(transaction, accounts: accounts, categories: categories)
                if !haystack.localizedCaseInsensitiveContains(query) { return false }
            }
            return true
        }
        return filtered.sorted { lhs, rhs in
            switch filter.sort {
            case .newest: lhs.date == rhs.date ? lhs.createdAt > rhs.createdAt : lhs.date > rhs.date
            case .oldest: lhs.date == rhs.date ? lhs.createdAt < rhs.createdAt : lhs.date < rhs.date
            case .highest: lhs.amountMinor == rhs.amountMinor ? lhs.date > rhs.date : lhs.amountMinor > rhs.amountMinor
            case .lowest: lhs.amountMinor == rhs.amountMinor ? lhs.date > rhs.date : lhs.amountMinor < rhs.amountMinor
            }
        }
    }

    static func grouped(_ items: [TransactionSnapshot], by grouping: TransactionGrouping, calendar: Calendar) -> [(date: Date, items: [TransactionSnapshot])] {
        switch grouping {
        case .none:
            return items.isEmpty ? [] : [(date: items[0].date, items: items)]
        case .day, .month:
            let component: Calendar.Component = grouping == .day ? .day : .month
            let groups = Dictionary(grouping: items) { item -> Date in
                if component == .day {
                    return calendar.startOfDay(for: item.date)
                }
                return calendar.dateInterval(of: .month, for: item.date)?.start ?? calendar.startOfDay(for: item.date)
            }
            return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
        }
    }

    private static func searchText(_ transaction: TransactionSnapshot, accounts: [AccountSnapshot], categories: [CategorySnapshot]) -> String {
        let account = accounts.first { $0.id == transaction.accountID }?.name ?? ""
        let counter = accounts.first { $0.id == transaction.counterAccountID }?.name ?? ""
        let category = categories.first { $0.id == transaction.categoryID }?.name ?? ""
        let subcategory = categories.first { $0.id == transaction.subcategoryID }?.name ?? ""
        let amount = MoneyText.plain(minor: transaction.amountMinor, code: transaction.currencyCode)
        return [transaction.notes, account, counter, category, subcategory, transaction.type.title, amount, transaction.tags.joined(separator: " ")]
            .joined(separator: " ")
    }
}
