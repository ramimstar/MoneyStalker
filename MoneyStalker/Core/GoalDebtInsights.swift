import Foundation

struct GoalProgress: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var targetMinor: Int64
    var currentMinor: Int64
    var remainingMinor: Int64
    var currencyCode: String
    var targetDate: Date?
    var basisPoints: Int64
    var isComplete: Bool
}

struct DebtSummary: Identifiable, Hashable, Sendable {
    var id: UUID
    var person: String
    var direction: DebtDirection
    var originalMinor: Int64
    var outstandingMinor: Int64
    var currencyCode: String
    var dueDate: Date?
    var status: DebtDisplayStatus
    var interestRateText: String
    var notes: String
}

enum GoalMath {
    static func progress(goal: GoalSnapshot, contributions: [ContributionSnapshot]) -> GoalProgress {
        let current = contributions.filter { $0.goalID == goal.id }.reduce(Int64(0)) { $0 + $1.amountMinor }
        let remaining = max(0, goal.targetMinor - current)
        let basis: Int64 = goal.targetMinor > 0 ? (current * 10_000) / goal.targetMinor : 0
        return GoalProgress(
            id: goal.id,
            name: goal.name,
            icon: goal.icon,
            colorHex: goal.colorHex,
            targetMinor: goal.targetMinor,
            currentMinor: current,
            remainingMinor: remaining,
            currencyCode: goal.currencyCode,
            targetDate: goal.targetDate,
            basisPoints: basis,
            isComplete: goal.targetMinor > 0 && current >= goal.targetMinor
        )
    }
}

enum DebtMath {
    static func outstanding(original: Int64, repayments: [Int64]) -> Int64 {
        max(0, original - repayments.reduce(0, +))
    }

    static func summary(debt: DebtSnapshot, repayments: [RepaymentSnapshot]) -> DebtSummary {
        let paid = repayments.filter { $0.debtID == debt.id }.map(\.amountMinor)
        let outstanding = outstanding(original: debt.originalMinor, repayments: paid)
        let status: DebtDisplayStatus
        if debt.isWrittenOff {
            status = .writtenOff
        } else if outstanding == 0 {
            status = .settled
        } else {
            status = .active
        }
        return DebtSummary(
            id: debt.id,
            person: debt.person,
            direction: debt.direction,
            originalMinor: debt.originalMinor,
            outstandingMinor: outstanding,
            currencyCode: debt.currencyCode,
            dueDate: debt.dueDate,
            status: status,
            interestRateText: debt.interestRateText,
            notes: debt.notes
        )
    }
}

struct Insight: Identifiable, Hashable, Sendable {
    var id: String
    var symbol: String
    var title: String
    var message: String
    var badge: String
    var tone: InsightTone
}

enum InsightTone: String, Hashable, Sendable {
    case neutral
    case accent
    case positive
    case negative
}

enum InsightsEngine {
    static func make(
        current: CashflowTotals,
        previous: CashflowTotals?,
        spending: [CategoryTotal],
        budgets: [BudgetStatus]
    ) -> [Insight] {
        var insights: [Insight] = []
        if current.incomeMinor == 0 && current.expenseMinor == 0 {
            insights.append(Insight(id: "empty", symbol: "tray", title: "No activity", message: "No income or expenses were recorded in this period.", badge: "—", tone: .neutral))
        }
        if let previous, previous.expenseMinor > 0, current.expenseMinor > 0 {
            let change = ((current.expenseMinor - previous.expenseMinor) * 10_000) / previous.expenseMinor
            let direction = change == 0 ? "unchanged from" : (change < 0 ? "lower than" : "higher than")
            let percent = MoneyText.percent(basisPoints: abs(change))
            let badge = change > 0 ? "+\(percent)" : (change < 0 ? "−\(percent)" : percent)
            let tone: InsightTone = change > 0 ? .negative : (change < 0 ? .positive : .neutral)
            insights.append(Insight(
                id: "compare",
                symbol: "chart.bar",
                title: "Spending comparison",
                message: "Expenses are \(direction) the previous period.",
                badge: badge,
                tone: tone
            ))
        } else if current.expenseMinor > 0, previous?.expenseMinor == 0 {
            insights.append(Insight(id: "compare-none", symbol: "chart.bar", title: "Spending comparison", message: "No expenses were recorded in the previous period, so there is no percentage comparison.", badge: "—", tone: .neutral))
        }
        if let top = spending.first, top.amountMinor > 0 {
            insights.append(Insight(id: "top", symbol: top.icon, title: "Largest category", message: "\(top.name) is the largest expense category in this period.", badge: top.name, tone: .accent))
        }
        if let rate = current.savingsRateBasisPoints {
            insights.append(Insight(id: "rate", symbol: "percent", title: "Savings rate", message: "Income minus expenses is \(MoneyText.percent(basisPoints: rate)) of income in this period.", badge: MoneyText.percent(basisPoints: rate), tone: rate < 0 ? .negative : .positive))
        }
        let over = budgets.filter(\.isOverBudget).map(\.name)
        if !over.isEmpty {
            let count = over.count
            insights.append(Insight(id: "over", symbol: "exclamationmark.triangle", title: "Over budget", message: over.joined(separator: ", ") + (count == 1 ? " is over its limit." : " are over their limits."), badge: count == 1 ? "1 category" : "\(count) categories", tone: .negative))
        }
        return insights
    }
}
