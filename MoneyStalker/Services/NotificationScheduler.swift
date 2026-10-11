import Foundation
import SwiftData
import UserNotifications

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onOpen: ((String) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let route = response.notification.request.content.userInfo["moneyStalker.route"] as? String ?? "home"
        let open = onOpen
        await MainActor.run { open?(route) }
    }
}

@MainActor
enum NotificationScheduler {
    private static let claimsKey = "moneyStalker.notification.claims"

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        registerCategories()
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func reconcile(context: ModelContext, settings: SettingsStore) async {
        registerCategories()
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let status = await authorizationStatus()
        let allowed = status == .authorized || status == .provisional || status == .ephemeral
        guard settings.notificationsEnabled, allowed else { return }

        let plan = plan(context: context, settings: settings)
        UserDefaults.standard.set(Array(plan.claims), forKey: claimsKey)
        for draft in plan.pending.prefix(48) {
            try? await center.add(request(for: draft, calendar: settings.calendar))
        }
        for draft in plan.immediate.prefix(8) {
            try? await center.add(request(for: draft, calendar: settings.calendar))
        }
    }

    static func sendTest() async -> Bool {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return false }
        let content = content(
            title: "Money Stalker",
            body: "Notifications are working on this iPhone.",
            route: "home"
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "moneyStalker.test.\(UUID().uuidString)", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    static func plan(context: ModelContext, settings: SettingsStore) -> NotificationPlan {
        let transactions = (try? context.fetch(FetchDescriptor<LedgerTransaction>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<SavingsGoal>())) ?? []
        let contributions = (try? context.fetch(FetchDescriptor<SavingsContribution>())) ?? []
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        let debts = (try? context.fetch(FetchDescriptor<Debt>())) ?? []
        let categorySnapshots = categories.map(\.snapshot)
        let transactionSnapshots = transactions.map(\.snapshot)
        let contributionSnapshots = contributions.map(\.snapshot)
        let statuses = budgets.filter { !$0.isArchived }.map {
            BudgetEngine.status(budget: $0.snapshot, transactions: transactionSnapshots, categories: categorySnapshots, now: .now, calendar: settings.calendar)
        }
        let progress = goals.map { GoalMath.progress(goal: $0.snapshot, contributions: contributionSnapshots) }
        let debtInputs = debts.compactMap { debt -> DebtReminderInput? in
            let summary = DebtMath.summary(debt: debt.snapshot, repayments: debt.repayments.map(\.snapshot))
            guard summary.status == .active, let due = summary.dueDate else { return nil }
            return DebtReminderInput(id: debt.id, name: debt.person, amountMinor: summary.outstandingMinor, currencyCode: debt.currencyCode, dueDate: due, isOpen: true)
        }
        let ruleInputs = rules.map { rule in
            RecurringReminderInput(
                id: rule.id,
                name: rule.name.isEmpty ? rule.type.title : rule.name,
                amountMinor: rule.amountMinor,
                currencyCode: rule.currencyCode,
                dueDate: rule.nextOccurrence,
                leadMinutes: rule.reminderLeadMinutes,
                isActive: !rule.isPaused && rule.reminderEnabled,
                isIncome: rule.type == .income
            )
        }
        let stored = UserDefaults.standard.stringArray(forKey: claimsKey) ?? []
        let input = NotificationContext(
            preferences: settings.notificationPreferences,
            currencyCode: settings.currencyCode,
            transactions: transactionSnapshots,
            categories: categorySnapshots,
            budgets: statuses,
            goals: progress,
            debts: debtInputs,
            rules: ruleInputs,
            claims: Set(stored)
        )
        return NotificationPlanner.plan(context: input, now: .now, calendar: settings.calendar)
    }

    private static func request(for draft: NotificationDraft, calendar: Calendar) -> UNNotificationRequest {
        let body = content(title: draft.title, body: draft.body, route: draft.route)
        let trigger = trigger(for: draft, calendar: calendar)
        return UNNotificationRequest(identifier: draft.identifier, content: body, trigger: trigger)
    }

    private static func content(title: String, body: String, route: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["moneyStalker.route": route]
        content.categoryIdentifier = route == "activity" ? "FINORA_RECORD" : "FINORA_OPEN"
        return content
    }

    private static func trigger(for draft: NotificationDraft, calendar: Calendar) -> UNNotificationTrigger? {
        guard let fire = draft.fireDate else { return nil }
        switch draft.repeatRule {
        case .none:
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        case .daily:
            var parts = DateComponents()
            parts.hour = calendar.component(.hour, from: fire)
            parts.minute = calendar.component(.minute, from: fire)
            parts.calendar = calendar
            parts.timeZone = calendar.timeZone
            return UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        case .monthly(let day):
            var parts = DateComponents()
            parts.day = day
            parts.hour = calendar.component(.hour, from: fire)
            parts.minute = calendar.component(.minute, from: fire)
            parts.calendar = calendar
            parts.timeZone = calendar.timeZone
            return UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        }
    }

    private static func registerCategories() {
        let open = UNNotificationAction(identifier: "FINORA_OPEN_ACTION", title: "Open", options: [.foreground])
        let add = UNNotificationAction(identifier: "FINORA_ADD_ACTION", title: "Add transaction", options: [.foreground])
        let review = UNNotificationCategory(identifier: "FINORA_OPEN", actions: [open], intentIdentifiers: [], options: [])
        let record = UNNotificationCategory(identifier: "FINORA_RECORD", actions: [add, open], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([review, record])
    }
}

@MainActor
enum BudgetAlertService {
    static func evaluate(context: ModelContext, settings: SettingsStore) async {
        await NotificationScheduler.reconcile(context: context, settings: settings)
    }
}
