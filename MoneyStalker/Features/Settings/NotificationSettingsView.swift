import SwiftUI
import UIKit
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: master) {
                    SettingsLabel(title: "Allow notifications", symbol: "bell.badge.fill", tint: SettingsTint.red)
                }
                Text(permissionText)
                    .font(.caption)
                    .foregroundStyle(Color.moneyStalkerSlate)
                if status == .denied {
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
                Button("Send a test notification") {
                    Task {
                        let sent = await NotificationScheduler.sendTest()
                        message = sent ? "A test notification will arrive in a few seconds." : "Allow notifications in iOS Settings before sending a test."
                    }
                }
            } footer: {
                Text("Money Stalker schedules reminders on this iPhone. It does not use a notification server. Daily and weekly money summaries are prepared from saved transactions the last time you open the app, because iOS cannot recalculate totals while Money Stalker is closed.")
            }

            if appModel.settings.notificationsEnabled {
                Section("Daily reminders") {
                    Toggle(isOn: flag(\.planningEnabled)) {
                        SettingsLabel(title: "Morning plan", symbol: "sun.max.fill", tint: SettingsTint.orange)
                    }
                    if appModel.settings.smartNotifications.planningEnabled {
                        DatePicker("Time", selection: time(\.planningMinutes), displayedComponents: .hourAndMinute)
                    }
                    Toggle(isOn: flag(\.expenseReminderEnabled)) {
                        SettingsLabel(title: "Expense reminder", symbol: "cart.fill", tint: SettingsTint.red)
                    }
                    if appModel.settings.smartNotifications.expenseReminderEnabled {
                        DatePicker("Time", selection: time(\.expenseMinutes), displayedComponents: .hourAndMinute)
                        Toggle("Skip after today's expenses are saved", isOn: flag(\.expenseOnlyIfEmpty))
                    }
                    Toggle(isOn: flag(\.dailySummaryEnabled)) {
                        SettingsLabel(title: "Daily summary", symbol: "list.clipboard.fill", tint: SettingsTint.blue)
                    }
                    if appModel.settings.smartNotifications.dailySummaryEnabled {
                        DatePicker("Time", selection: time(\.dailySummaryMinutes), displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Toggle(isOn: stored(\.budgetAlertsEnabled)) {
                        SettingsLabel(title: "Budget alerts", symbol: "chart.pie.fill", tint: SettingsTint.green)
                    }
                    if appModel.settings.budgetAlertsEnabled {
                        ForEach([50, 80, 90, 100], id: \.self) { value in
                            Toggle("\(value)% of a budget", isOn: threshold(value))
                        }
                    }
                } header: {
                    Text("Budgets")
                } footer: {
                    Text("Money Stalker alerts you once for each threshold in the current budget period. The alert uses the real spent amount.")
                }

                Section {
                    Toggle(isOn: stored(\.debtRemindersEnabled)) {
                        SettingsLabel(title: "Bill reminders", symbol: "calendar", tint: SettingsTint.red)
                    }
                    if appModel.settings.debtRemindersEnabled {
                        Picker("Remind me", selection: leadDays) {
                            Text("1 day before").tag(1)
                            Text("3 days before").tag(3)
                            Text("7 days before").tag(7)
                        }
                    }
                } footer: {
                    Text("Money Stalker uses unpaid debts with a due date as bills. Settled and written-off debts are skipped.")
                }

                Section {
                    Toggle(isOn: stored(\.recurringRemindersEnabled)) {
                        SettingsLabel(title: "Recurring payments", symbol: "repeat", tint: SettingsTint.purple)
                    }
                } footer: {
                    Text("A reminder is sent only for an active schedule whose own reminder switch is on. Paused schedules are skipped.")
                }

                Section("Reports") {
                    Toggle(isOn: flag(\.weeklyReportEnabled)) {
                        SettingsLabel(title: "Weekly report", symbol: "chart.bar.fill", tint: SettingsTint.indigo)
                    }
                    if appModel.settings.smartNotifications.weeklyReportEnabled {
                        Picker("Day", selection: weekday) {
                            Text("Sunday").tag(1)
                            Text("Monday").tag(2)
                            Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4)
                            Text("Thursday").tag(5)
                            Text("Friday").tag(6)
                            Text("Saturday").tag(7)
                        }
                        DatePicker("Time", selection: time(\.weeklyMinutes), displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Toggle(isOn: flag(\.savingsMilestonesEnabled)) {
                        SettingsLabel(title: "Savings milestones", symbol: "flag.fill", tint: SettingsTint.green)
                    }
                    Toggle(isOn: flag(\.inactivityEnabled)) {
                        SettingsLabel(title: "Inactivity reminder", symbol: "clock.fill", tint: SettingsTint.orange)
                    }
                    if appModel.settings.smartNotifications.inactivityEnabled {
                        Stepper("After \(appModel.settings.smartNotifications.inactivityDays) days", value: days, in: 2...30)
                    }
                    Toggle(isOn: incomeToggle) {
                        SettingsLabel(title: "Income day", symbol: "banknote.fill", tint: SettingsTint.teal)
                    }
                    if appModel.settings.smartNotifications.incomeReminderEnabled {
                        Stepper("Day \(max(1, appModel.settings.smartNotifications.incomeDay))", value: incomeDay, in: 1...28)
                        DatePicker("Time", selection: time(\.incomeMinutes), displayedComponents: .hourAndMinute)
                    }
                    Toggle(isOn: flag(\.unusualSpendingEnabled)) {
                        SettingsLabel(title: "Unusual spending", symbol: "exclamationmark.triangle.fill", tint: SettingsTint.pink)
                    }
                    if appModel.settings.smartNotifications.unusualSpendingEnabled {
                        Picker("Compared with your usual month", selection: unusual) {
                            Text("50% higher").tag(150)
                            Text("Double").tag(200)
                        }
                    }
                } header: {
                    Text("Insights")
                } footer: {
                    Text("Unusual spending waits until a category has spending in three earlier months. Income day stays off until you choose a date. Money Stalker does not assume a salary day.")
                }

                Section("Privacy") {
                    Toggle(isOn: flag(\.hideAmounts)) {
                        SettingsLabel(title: "Hide amounts", symbol: "eye.slash.fill", tint: SettingsTint.gray)
                    }
                    Text("When this is on, reminder text leaves out money amounts. Budget alerts still include the percentage used.")
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .moneyStalkerScreen()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { status = await NotificationScheduler.authorizationStatus() }
        .alert("Notifications", isPresented: messageShown) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var permissionText: String {
        switch status {
        case .denied: "iOS is blocking notifications. Turn them on in Settings to receive reminders."
        case .authorized, .provisional, .ephemeral: "iOS permission is on. The switch above turns Money Stalker reminders on or off."
        default: "Money Stalker asks for permission when you turn reminders on. Titles and messages stay in English."
        }
    }

    private var messageShown: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }

    private var master: Binding<Bool> {
        Binding(get: { appModel.settings.notificationsEnabled }, set: { newValue in
            if newValue {
                Task {
                    let granted = await NotificationScheduler.requestAuthorization()
                    appModel.settings.notificationsEnabled = granted
                    status = await NotificationScheduler.authorizationStatus()
                    if !granted { message = "Notifications stay off until iOS permission is allowed." }
                    await NotificationScheduler.reconcile(context: context, settings: appModel.settings)
                }
            } else {
                appModel.settings.notificationsEnabled = false
                Task { await NotificationScheduler.reconcile(context: context, settings: appModel.settings) }
            }
        })
    }

    private func stored(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Bool>) -> Binding<Bool> {
        Binding(get: { appModel.settings[keyPath: keyPath] }, set: { value in
            appModel.settings[keyPath: keyPath] = value
            refresh()
        })
    }

    private func flag(_ keyPath: WritableKeyPath<SmartNotificationSettings, Bool>) -> Binding<Bool> {
        Binding(get: { appModel.settings.smartNotifications[keyPath: keyPath] }, set: { value in
            update { $0[keyPath: keyPath] = value }
        })
    }

    private func time(_ keyPath: WritableKeyPath<SmartNotificationSettings, Int>) -> Binding<Date> {
        Binding(get: {
            let minutes = appModel.settings.smartNotifications[keyPath: keyPath]
            return appModel.settings.calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let parts = appModel.settings.calendar.dateComponents([.hour, .minute], from: date)
            update { $0[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
        })
    }

    private var leadDays: Binding<Int> {
        Binding(get: { appModel.settings.smartNotifications.billLeadDays }, set: { value in update { $0.billLeadDays = value } })
    }

    private var weekday: Binding<Int> {
        Binding(get: { appModel.settings.smartNotifications.weeklyWeekday }, set: { value in update { $0.weeklyWeekday = value } })
    }

    private var days: Binding<Int> {
        Binding(get: { appModel.settings.smartNotifications.inactivityDays }, set: { value in update { $0.inactivityDays = value } })
    }

    private var incomeDay: Binding<Int> {
        Binding(get: { max(1, appModel.settings.smartNotifications.incomeDay) }, set: { value in update { $0.incomeDay = value } })
    }

    private var incomeToggle: Binding<Bool> {
        Binding(get: { appModel.settings.smartNotifications.incomeReminderEnabled }, set: { on in
            update {
                $0.incomeReminderEnabled = on
                if on && $0.incomeDay < 1 { $0.incomeDay = 1 }
            }
        })
    }

    private var unusual: Binding<Int> {
        Binding(get: { appModel.settings.smartNotifications.unusualPercent }, set: { value in update { $0.unusualPercent = value } })
    }

    private func threshold(_ value: Int) -> Binding<Bool> {
        Binding(get: { appModel.settings.smartNotifications.budgetThresholds.contains(value) }, set: { on in
            update {
                if on {
                    if !$0.budgetThresholds.contains(value) { $0.budgetThresholds.append(value) }
                } else {
                    $0.budgetThresholds.removeAll { $0 == value }
                }
                $0.budgetThresholds.sort()
            }
        })
    }

    private func update(_ change: (inout SmartNotificationSettings) -> Void) {
        var copy = appModel.settings.smartNotifications
        change(&copy)
        appModel.settings.smartNotifications = copy
        refresh()
    }

    private func refresh() {
        Task { await NotificationScheduler.reconcile(context: context, settings: appModel.settings) }
    }
}
