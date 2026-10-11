import Foundation

struct BudgetStatus: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var currencyCode: String
    var limitMinor: Int64
    var spentMinor: Int64
    var availableMinor: Int64
    var remainingMinor: Int64
    var consumedBasisPoints: Int64
    var isOverBudget: Bool
    var isWarning: Bool
    var previousSpentMinor: Int64?
    var period: DateWindow
}

enum BudgetEngine {
    static func periods(kind: BudgetPeriodKind, start: Date, end: Date?, now: Date, calendar: Calendar) -> [DateWindow] {
        switch kind {
        case .custom:
            return [DateWindow.covering(startDay: start, endDay: end ?? start, calendar: calendar)]
        case .weekly, .monthly:
            var cursor = calendar.startOfDay(for: start)
            let horizon = max(now, cursor)
            var windows: [DateWindow] = []
            var safety = 0
            while cursor <= horizon && safety < 600 {
                safety += 1
                let next: Date?
                if kind == .weekly {
                    next = calendar.date(byAdding: .day, value: 7, to: cursor)
                } else {
                    next = calendar.date(byAdding: .month, value: 1, to: cursor)
                }
                guard let next else { break }
                windows.append(DateWindow(start: cursor, end: next))
                cursor = next
            }
            if windows.isEmpty {
                let next = kind == .weekly
                    ? calendar.date(byAdding: .day, value: 7, to: cursor)
                    : calendar.date(byAdding: .month, value: 1, to: cursor)
                if let next {
                    windows.append(DateWindow(start: cursor, end: next))
                }
            }
            return windows
        }
    }

    static func status(
        budget: BudgetSnapshot,
        transactions: [TransactionSnapshot],
        categories: [CategorySnapshot],
        now: Date,
        calendar: Calendar
    ) -> BudgetStatus {
        let windows = periods(kind: budget.kind, start: budget.startDate, end: budget.endDate, now: now, calendar: calendar)
        var carry: Int64 = 0
        var previous: Int64?
        var currentSpent: Int64 = 0
        var currentWindow = windows.last ?? DateWindow.covering(startDay: budget.startDate, endDay: budget.endDate ?? now, calendar: calendar)
        for (index, window) in windows.enumerated() {
            let spent = spentMinor(budget: budget, window: window, transactions: transactions, categories: categories)
            let isCurrent = index == windows.count - 1
            if isCurrent {
                currentSpent = spent
                currentWindow = window
            } else if budget.rollover && budget.kind != .custom {
                carry += budget.limitMinor - spent
                previous = spent
            } else if index == windows.count - 2 {
                previous = spent
            }
        }
        let available = budget.limitMinor + (budget.rollover && budget.kind != .custom ? carry : 0)
        let remaining = available - currentSpent
        let consumed: Int64
        if available <= 0 {
            consumed = currentSpent > 0 ? 10_000 : 0
        } else {
            consumed = (currentSpent * 10_000) / available
        }
        let over = currentSpent > available
        let warning = !over && available > 0 && currentSpent * 10_000 >= available * budget.warningThresholdBasisPoints
        return BudgetStatus(
            id: budget.id,
            name: budget.name,
            currencyCode: budget.currencyCode,
            limitMinor: budget.limitMinor,
            spentMinor: currentSpent,
            availableMinor: available,
            remainingMinor: remaining,
            consumedBasisPoints: consumed,
            isOverBudget: over,
            isWarning: warning,
            previousSpentMinor: previous,
            period: currentWindow
        )
    }

    static func spentMinor(
        budget: BudgetSnapshot,
        window: DateWindow,
        transactions: [TransactionSnapshot],
        categories: [CategorySnapshot]
    ) -> Int64 {
        transactions.reduce(into: Int64(0)) { total, transaction in
            guard transaction.type == .expense else { return }
            guard window.contains(transaction.date) else { return }
            guard transaction.currencyCode == budget.currencyCode else { return }
            guard categoryMatches(transaction.effectiveCategoryID, budgetCategoryID: budget.categoryID, categories: categories) else { return }
            total += transaction.amountMinor
        }
    }

    static func categoryMatches(_ categoryID: UUID?, budgetCategoryID: UUID?, categories: [CategorySnapshot]) -> Bool {
        guard let budgetCategoryID else { return true }
        guard let categoryID else { return false }
        if categoryID == budgetCategoryID { return true }
        return categories.first { $0.id == categoryID }?.parentID == budgetCategoryID
    }
}
