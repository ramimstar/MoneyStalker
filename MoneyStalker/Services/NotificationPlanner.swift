import Foundation

struct SmartNotificationSettings: Codable, Equatable, Sendable {
    var planningEnabled: Bool
    var planningMinutes: Int
    var expenseReminderEnabled: Bool
    var expenseMinutes: Int
    var expenseOnlyIfEmpty: Bool
    var dailySummaryEnabled: Bool
    var dailySummaryMinutes: Int
    var budgetThresholds: [Int]
    var billLeadDays: Int
    var weeklyReportEnabled: Bool
    var weeklyWeekday: Int
    var weeklyMinutes: Int
    var savingsMilestonesEnabled: Bool
    var inactivityEnabled: Bool
    var inactivityDays: Int
    var incomeReminderEnabled: Bool
    var incomeDay: Int
    var incomeMinutes: Int
    var unusualSpendingEnabled: Bool
    var unusualPercent: Int
    var hideAmounts: Bool

    init(
        planningEnabled: Bool = true,
        planningMinutes: Int = 9 * 60,
        expenseReminderEnabled: Bool = true,
        expenseMinutes: Int = 20 * 60 + 30,
        expenseOnlyIfEmpty: Bool = true,
        dailySummaryEnabled: Bool = false,
        dailySummaryMinutes: Int = 21 * 60,
        budgetThresholds: [Int] = [80, 100],
        billLeadDays: Int = 1,
        weeklyReportEnabled: Bool = false,
        weeklyWeekday: Int = 1,
        weeklyMinutes: Int = 20 * 60,
        savingsMilestonesEnabled: Bool = true,
        inactivityEnabled: Bool = false,
        inactivityDays: Int = 3,
        incomeReminderEnabled: Bool = false,
        incomeDay: Int = 0,
        incomeMinutes: Int = 9 * 60,
        unusualSpendingEnabled: Bool = false,
        unusualPercent: Int = 150,
        hideAmounts: Bool = false
    ) {
        self.planningEnabled = planningEnabled
        self.planningMinutes = planningMinutes
        self.expenseReminderEnabled = expenseReminderEnabled
        self.expenseMinutes = expenseMinutes
        self.expenseOnlyIfEmpty = expenseOnlyIfEmpty
        self.dailySummaryEnabled = dailySummaryEnabled
        self.dailySummaryMinutes = dailySummaryMinutes
        self.budgetThresholds = budgetThresholds
        self.billLeadDays = billLeadDays
        self.weeklyReportEnabled = weeklyReportEnabled
        self.weeklyWeekday = weeklyWeekday
        self.weeklyMinutes = weeklyMinutes
        self.savingsMilestonesEnabled = savingsMilestonesEnabled
        self.inactivityEnabled = inactivityEnabled
        self.inactivityDays = inactivityDays
        self.incomeReminderEnabled = incomeReminderEnabled
        self.incomeDay = incomeDay
        self.incomeMinutes = incomeMinutes
        self.unusualSpendingEnabled = unusualSpendingEnabled
        self.unusualPercent = unusualPercent
        self.hideAmounts = hideAmounts
    }

    init(from decoder: Decoder) throws {
        let defaults = SmartNotificationSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planningEnabled = try container.decodeIfPresent(Bool.self, forKey: .planningEnabled) ?? defaults.planningEnabled
        planningMinutes = try container.decodeIfPresent(Int.self, forKey: .planningMinutes) ?? defaults.planningMinutes
        expenseReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .expenseReminderEnabled) ?? defaults.expenseReminderEnabled
        expenseMinutes = try container.decodeIfPresent(Int.self, forKey: .expenseMinutes) ?? defaults.expenseMinutes
        expenseOnlyIfEmpty = try container.decodeIfPresent(Bool.self, forKey: .expenseOnlyIfEmpty) ?? defaults.expenseOnlyIfEmpty
        dailySummaryEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailySummaryEnabled) ?? defaults.dailySummaryEnabled
        dailySummaryMinutes = try container.decodeIfPresent(Int.self, forKey: .dailySummaryMinutes) ?? defaults.dailySummaryMinutes
        budgetThresholds = try container.decodeIfPresent([Int].self, forKey: .budgetThresholds) ?? defaults.budgetThresholds
        billLeadDays = try container.decodeIfPresent(Int.self, forKey: .billLeadDays) ?? defaults.billLeadDays
        weeklyReportEnabled = try container.decodeIfPresent(Bool.self, forKey: .weeklyReportEnabled) ?? defaults.weeklyReportEnabled
        weeklyWeekday = try container.decodeIfPresent(Int.self, forKey: .weeklyWeekday) ?? defaults.weeklyWeekday
        weeklyMinutes = try container.decodeIfPresent(Int.self, forKey: .weeklyMinutes) ?? defaults.weeklyMinutes
        savingsMilestonesEnabled = try container.decodeIfPresent(Bool.self, forKey: .savingsMilestonesEnabled) ?? defaults.savingsMilestonesEnabled
        inactivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .inactivityEnabled) ?? defaults.inactivityEnabled
        inactivityDays = try container.decodeIfPresent(Int.self, forKey: .inactivityDays) ?? defaults.inactivityDays
        incomeReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .incomeReminderEnabled) ?? defaults.incomeReminderEnabled
        incomeDay = try container.decodeIfPresent(Int.self, forKey: .incomeDay) ?? defaults.incomeDay
        incomeMinutes = try container.decodeIfPresent(Int.self, forKey: .incomeMinutes) ?? defaults.incomeMinutes
        unusualSpendingEnabled = try container.decodeIfPresent(Bool.self, forKey: .unusualSpendingEnabled) ?? defaults.unusualSpendingEnabled
        unusualPercent = try container.decodeIfPresent(Int.self, forKey: .unusualPercent) ?? defaults.unusualPercent
        hideAmounts = try container.decodeIfPresent(Bool.self, forKey: .hideAmounts) ?? defaults.hideAmounts
    }
}

struct NotificationPreferences: Equatable, Sendable {
    var enabled: Bool
    var budgetAlertsEnabled: Bool
    var recurringRemindersEnabled: Bool
    var billRemindersEnabled: Bool
    var smart: SmartNotificationSettings
}

struct DebtReminderInput: Equatable, Sendable {
    var id: UUID
    var name: String
    var amountMinor: Int64
    var currencyCode: String
    var dueDate: Date
    var isOpen: Bool
}

struct RecurringReminderInput: Equatable, Sendable {
    var id: UUID
    var name: String
    var amountMinor: Int64
    var currencyCode: String
    var dueDate: Date
    var leadMinutes: Int
    var isActive: Bool
    var isIncome: Bool
}

struct NotificationDraft: Equatable, Sendable {
    var identifier: String
    var title: String
    var body: String
    var fireDate: Date?
    var repeatRule: NotificationRepeat
    var route: String
}

enum NotificationRepeat: Equatable, Sendable {
    case none
    case daily
    case monthly(day: Int)
}

struct NotificationContext: Equatable, Sendable {
    var preferences: NotificationPreferences
    var currencyCode: String
    var transactions: [TransactionSnapshot]
    var categories: [CategorySnapshot]
    var budgets: [BudgetStatus]
    var goals: [GoalProgress]
    var debts: [DebtReminderInput]
    var rules: [RecurringReminderInput]
    var claims: Set<String>
}

struct NotificationPlan: Equatable, Sendable {
    var pending: [NotificationDraft]
    var immediate: [NotificationDraft]
    var claims: Set<String>
}

enum NotificationPlanner {
    static func plan(context: NotificationContext, now: Date, calendar: Calendar) -> NotificationPlan {
        guard context.preferences.enabled else {
            return NotificationPlan(pending: [], immediate: [], claims: context.claims)
        }
        let smart = context.preferences.smart
        var pending: [NotificationDraft] = []
        var immediate: [NotificationDraft] = []
        var claims = context.claims

        if smart.planningEnabled {
            let fire = nextDaily(minutes: smart.planningMinutes, now: now, calendar: calendar)
            pending.append(NotificationDraft(
                identifier: "moneyStalker.plan.daily",
                title: "Good Morning! ☀️",
                body: "Plan today's spending and stay on track with your budget.",
                fireDate: fire,
                repeatRule: .daily,
                route: "home"
            ))
        }

        if smart.expenseReminderEnabled {
            pending.append(expenseReminder(context: context, now: now, calendar: calendar))
        }

        if smart.dailySummaryEnabled, let summary = dailySummary(context: context, now: now, calendar: calendar) {
            pending.append(summary)
        }

        if smart.weeklyReportEnabled, let weekly = weeklyReport(context: context, now: now, calendar: calendar) {
            pending.append(weekly)
        }

        if smart.incomeReminderEnabled, smart.incomeDay >= 1 {
            let day = min(smart.incomeDay, 28)
            let fire = nextMonthDay(day, minutes: smart.incomeMinutes, now: now, calendar: calendar)
            pending.append(NotificationDraft(
                identifier: "moneyStalker.income.monthly",
                title: "Income Day Reminder 💰",
                body: "It's your expected income day. Remember to update your income records.",
                fireDate: fire,
                repeatRule: .monthly(day: day),
                route: "activity"
            ))
        }

        if smart.inactivityEnabled, let reminder = inactivityReminder(context: context, now: now, calendar: calendar, claims: &claims) {
            pending.append(reminder)
        }

        if context.preferences.budgetAlertsEnabled {
            immediate.append(contentsOf: budgetAlerts(context: context, claims: &claims))
        } else {
            claims = claims.filter { !$0.hasPrefix("moneyStalker.claim.budget.") }
        }

        if smart.savingsMilestonesEnabled {
            immediate.append(contentsOf: savingsAlerts(context: context, claims: &claims))
        }

        if smart.unusualSpendingEnabled {
            immediate.append(contentsOf: unusualAlerts(context: context, now: now, calendar: calendar, claims: &claims))
        }

        if context.preferences.billRemindersEnabled {
            pending.append(contentsOf: billReminders(context: context, now: now, calendar: calendar))
        }

        if context.preferences.recurringRemindersEnabled {
            pending.append(contentsOf: recurringReminders(context: context, now: now, calendar: calendar))
        }

        return NotificationPlan(pending: pending, immediate: immediate, claims: claims)
    }

    static func expenseReminder(context: NotificationContext, now: Date, calendar: Calendar) -> NotificationDraft {
        let smart = context.preferences.smart
        var fire = nextDaily(minutes: smart.expenseMinutes, now: now, calendar: calendar)
        if smart.expenseOnlyIfEmpty, hasExpense(on: fire, context: context, calendar: calendar) {
            fire = calendar.date(byAdding: .day, value: 1, to: fire) ?? fire
        }
        let repeats: NotificationRepeat = smart.expenseOnlyIfEmpty ? .none : .daily
        return NotificationDraft(
            identifier: "moneyStalker.expense.reminder",
            title: "Don't Forget Today's Expenses 🧾",
            body: "Have you recorded all your expenses for today? Take a moment to update your transactions.",
            fireDate: fire,
            repeatRule: repeats,
            route: "activity"
        )
    }

    static func dailySummary(context: NotificationContext, now: Date, calendar: Calendar) -> NotificationDraft? {
        let fire = nextDaily(minutes: context.preferences.smart.dailySummaryMinutes, now: now, calendar: calendar)
        guard calendar.isDate(fire, inSameDayAs: now) else { return nil }
        let day = DateWindow(start: calendar.startOfDay(for: fire), end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: fire)) ?? fire)
        let flow = LedgerCalculator.cashflow(transactions: context.transactions, window: day, currencyCode: context.currencyCode)
        let body: String
        if context.preferences.smart.hideAmounts {
            body = "Your daily money summary is ready in Money Stalker."
        } else if flow.incomeMinor == 0 && flow.expenseMinor == 0 {
            body = "No income or expenses have been recorded today."
        } else {
            let income = money(flow.incomeMinor, context.currencyCode)
            let expenses = money(flow.expenseMinor, context.currencyCode)
            body = "So far today, income was \(income) and expenses were \(expenses)."
        }
        return NotificationDraft(
            identifier: "moneyStalker.summary.daily",
            title: "Your Daily Money Summary 📊",
            body: body,
            fireDate: fire,
            repeatRule: .none,
            route: "home"
        )
    }

    static func weeklyReport(context: NotificationContext, now: Date, calendar: Calendar) -> NotificationDraft? {
        let smart = context.preferences.smart
        let fire = nextWeekday(smart.weeklyWeekday, minutes: smart.weeklyMinutes, now: now, calendar: calendar)
        guard let week = previousCompleteWeek(before: fire, calendar: calendar), now >= week.end else { return nil }
        let flow = LedgerCalculator.cashflow(transactions: context.transactions, window: week, currencyCode: context.currencyCode)
        let body: String
        if context.preferences.smart.hideAmounts {
            body = "Your weekly money report is ready in Money Stalker."
        } else {
            let income = money(flow.incomeMinor, context.currencyCode)
            let expenses = money(flow.expenseMinor, context.currencyCode)
            let net = money(flow.netMinor, context.currencyCode)
            body = "Last week, you earned \(income), spent \(expenses), and had a net cash flow of \(net)."
        }
        return NotificationDraft(
            identifier: "moneyStalker.summary.weekly",
            title: "Your Weekly Money Report 📈",
            body: body,
            fireDate: fire,
            repeatRule: .none,
            route: "home"
        )
    }

    static func budgetAlerts(context: NotificationContext, claims: inout Set<String>) -> [NotificationDraft] {
        let thresholds = context.preferences.smart.budgetThresholds.filter { (50...100).contains($0) }.sorted()
        var drafts: [NotificationDraft] = []
        for status in context.budgets {
            let period = Int(status.period.start.timeIntervalSince1970)
            let prefix = "moneyStalker.claim.budget.\(status.id.uuidString).\(period)."
            for threshold in thresholds where status.consumedBasisPoints < threshold * 100 {
                claims.remove(prefix + "\(threshold)")
            }
            let crossed = thresholds.filter { status.consumedBasisPoints >= $0 * 100 && !claims.contains(prefix + "\($0)") }
            guard let highest = crossed.max() else { continue }
            for threshold in thresholds where status.consumedBasisPoints >= threshold * 100 {
                claims.insert(prefix + "\(threshold)")
            }
            let percent = MoneyText.percent(basisPoints: status.consumedBasisPoints).replacingOccurrences(of: "%", with: "")
            let body: String
            if status.isOverBudget {
                body = "You've gone over your \(status.name) budget."
            } else if highest >= 100 {
                body = "You've used \(percent)% of your \(status.name) budget."
            } else if context.preferences.smart.hideAmounts {
                body = "You've used \(percent)% of your \(status.name) budget. Keep an eye on your remaining balance."
            } else {
                let left = money(max(0, status.remainingMinor), status.currencyCode)
                body = "You've used \(percent)% of your \(status.name) budget. \(left) is still available."
            }
            drafts.append(NotificationDraft(
                identifier: "moneyStalker.budget.\(status.id.uuidString).\(period).\(highest)",
                title: "Budget Alert ⚠️",
                body: body,
                fireDate: nil,
                repeatRule: .none,
                route: "budgets"
            ))
        }
        return drafts
    }

    static func savingsAlerts(context: NotificationContext, claims: inout Set<String>) -> [NotificationDraft] {
        var drafts: [NotificationDraft] = []
        for goal in context.goals {
            let key = "moneyStalker.claim.goal.\(goal.id.uuidString).complete"
            if goal.isComplete {
                guard !claims.contains(key) else { continue }
                claims.insert(key)
                drafts.append(NotificationDraft(
                    identifier: key,
                    title: "Savings Goal Achieved! 🎉",
                    body: "Congratulations! You've reached your \(goal.name) savings target.",
                    fireDate: nil,
                    repeatRule: .none,
                    route: "goals"
                ))
            } else {
                claims.remove(key)
            }
        }
        return drafts
    }

    static func unusualAlerts(context: NotificationContext, now: Date, calendar: Calendar, claims: inout Set<String>) -> [NotificationDraft] {
        guard let current = calendar.dateInterval(of: .month, for: now) else { return [] }
        let currentWindow = DateWindow(start: current.start, end: current.end)
        var previous: [DateWindow] = []
        var cursor = current.start
        for _ in 0..<3 {
            guard let earlier = calendar.date(byAdding: .month, value: -1, to: cursor),
                  let interval = calendar.dateInterval(of: .month, for: earlier) else { break }
            previous.append(DateWindow(start: interval.start, end: interval.end))
            cursor = interval.start
        }
        guard previous.count == 3 else { return [] }
        var drafts: [NotificationDraft] = []
        let currentTotals = LedgerCalculator.categoryTotals(transactions: context.transactions, categories: context.categories, kind: .expense, window: currentWindow, currencyCode: context.currencyCode, rollUpToParent: true)
        for item in currentTotals where item.amountMinor > 0 {
            let history = previous.map { window in
                LedgerCalculator.categoryTotals(transactions: context.transactions, categories: context.categories, kind: .expense, window: window, currencyCode: context.currencyCode, rollUpToParent: true)
                    .first { $0.id == item.id }?.amountMinor ?? 0
            }
            let samples = history.filter { $0 > 0 }
            guard samples.count >= 3 else { continue }
            let average = samples.reduce(Int64(0), +) / Int64(samples.count)
            guard average > 0 else { continue }
            let threshold = average * Int64(max(110, context.preferences.smart.unusualPercent)) / 100
            guard item.amountMinor > threshold else { continue }
            let key = "moneyStalker.claim.unusual.\(item.id.uuidString).\(Int(current.start.timeIntervalSince1970))"
            guard !claims.contains(key) else { continue }
            claims.insert(key)
            drafts.append(NotificationDraft(
                identifier: key,
                title: "Unusual Spending Detected 📉",
                body: "Your spending on \(item.name) is higher than usual. Review your recent transactions.",
                fireDate: nil,
                repeatRule: .none,
                route: "activity"
            ))
        }
        return drafts
    }

    static func billReminders(context: NotificationContext, now: Date, calendar: Calendar) -> [NotificationDraft] {
        let lead = [1, 3, 7].contains(context.preferences.smart.billLeadDays) ? context.preferences.smart.billLeadDays : 1
        return context.debts.compactMap { debt in
            guard debt.isOpen else { return nil }
            guard let day = calendar.date(byAdding: .day, value: -lead, to: calendar.startOfDay(for: debt.dueDate)) else { return nil }
            guard let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day), fire > now else { return nil }
            let amount = context.preferences.smart.hideAmounts ? nil : money(debt.amountMinor, debt.currencyCode)
            let due = dayText(debt.dueDate, calendar: calendar)
            let body = amount.map { "Your \(debt.name) payment of \($0) is due on \(due)." } ?? "Your \(debt.name) payment is due on \(due)."
            return NotificationDraft(
                identifier: "moneyStalker.bill.\(debt.id.uuidString).\(Int(calendar.startOfDay(for: debt.dueDate).timeIntervalSince1970))",
                title: "Upcoming Bill Reminder 📅",
                body: body,
                fireDate: fire,
                repeatRule: .none,
                route: "debts"
            )
        }
    }

    static func recurringReminders(context: NotificationContext, now: Date, calendar: Calendar) -> [NotificationDraft] {
        context.rules.compactMap { rule in
            guard rule.isActive else { return nil }
            let fire = rule.dueDate.addingTimeInterval(TimeInterval(-rule.leadMinutes * 60))
            guard fire > now else { return nil }
            let due = dayText(rule.dueDate, calendar: calendar)
            let body: String
            if context.preferences.smart.hideAmounts {
                body = rule.isIncome
                    ? "Your \(rule.name) is scheduled for \(due)."
                    : "Your \(rule.name) payment is scheduled for \(due)."
            } else {
                let amount = money(rule.amountMinor, rule.currencyCode)
                body = rule.isIncome
                    ? "Your \(rule.name) of \(amount) is scheduled for \(due)."
                    : "Your \(rule.name) payment of \(amount) is scheduled for \(due)."
            }
            return NotificationDraft(
                identifier: "moneyStalker.rule.\(rule.id.uuidString).\(Int(rule.dueDate.timeIntervalSince1970))",
                title: "Upcoming Payment 💳",
                body: body,
                fireDate: fire,
                repeatRule: .none,
                route: "recurring"
            )
        }
    }

    static func inactivityReminder(context: NotificationContext, now: Date, calendar: Calendar, claims: inout Set<String>) -> NotificationDraft? {
        let dates = context.transactions.map(\.date)
        guard let latest = dates.max() else { return nil }
        let days = max(1, context.preferences.smart.inactivityDays)
        guard let limit = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: latest)), now >= limit else { return nil }
        let key = "moneyStalker.claim.idle.\(Int(calendar.startOfDay(for: latest).timeIntervalSince1970))"
        guard !claims.contains(key) else { return nil }
        claims.insert(key)
        let fire = nextDaily(minutes: 10 * 60, now: now, calendar: calendar)
        return NotificationDraft(
            identifier: key,
            title: "Keep Your Money Tracker Updated 💚",
            body: "It's been a while since your last transaction. Update your finances to keep your records accurate.",
            fireDate: fire,
            repeatRule: .none,
            route: "activity"
        )
    }

    static func hasExpense(on fire: Date, context: NotificationContext, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: fire)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        let window = DateWindow(start: start, end: end)
        return context.transactions.contains { $0.type == .expense && window.contains($0.date) }
    }

    static func previousCompleteWeek(before fire: Date, calendar: Calendar) -> DateWindow? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: fire) else { return nil }
        guard let start = calendar.date(byAdding: .day, value: -7, to: week.start) else { return nil }
        return DateWindow(start: start, end: week.start)
    }

    static func nextDaily(minutes: Int, now: Date, calendar: Calendar) -> Date {
        let hour = min(23, max(0, minutes / 60))
        let minute = min(59, max(0, minutes % 60))
        let start = calendar.startOfDay(for: now)
        let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? now
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    static func nextWeekday(_ weekday: Int, minutes: Int, now: Date, calendar: Calendar) -> Date {
        var candidate = nextDaily(minutes: minutes, now: now, calendar: calendar)
        for _ in 0..<8 {
            if calendar.component(.weekday, from: candidate) == weekday { return candidate }
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    static func nextMonthDay(_ day: Int, minutes: Int, now: Date, calendar: Calendar) -> Date {
        func composed(_ base: Date) -> Date? {
            var parts = calendar.dateComponents([.year, .month], from: base)
            parts.day = min(max(1, day), 28)
            parts.hour = min(23, max(0, minutes / 60))
            parts.minute = min(59, max(0, minutes % 60))
            parts.second = 0
            return calendar.date(from: parts)
        }
        if let thisMonth = composed(now), thisMonth > now { return thisMonth }
        let next = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        return composed(next) ?? now
    }

    static func money(_ minor: Int64, _ code: String) -> String {
        MoneyText.string(minor: minor, code: code, locale: Locale(identifier: "en_US"))
    }

    static func dayText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
