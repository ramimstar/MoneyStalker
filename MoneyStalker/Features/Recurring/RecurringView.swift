import SwiftData
import SwiftUI

struct RecurringListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringRule.nextOccurrence) private var rules: [RecurringRule]
    @State private var showEditor = false

    var body: some View {
        List {
            Section {
                Text("Scheduled items post when you open Money Stalker. They are not income or expenses until a real transaction is created. Deleting a posted occurrence does not recreate that same date.")
                    .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
            }
            ForEach(rules) { rule in
                NavigationLink(value: AppRoute.recurring(rule.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rule.name.isEmpty ? rule.type.title : rule.name).font(.body.weight(.semibold))
                            if rule.isPaused { Text("Paused").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Color.moneyStalkerWarning.opacity(0.2)).clipShape(Capsule()) }
                        }
                        Text("\(rule.frequency.title) · next \(DateFormatting.string(from: rule.nextOccurrence, style: appModel.settings.dateStyle, locale: appModel.settings.formattingLocale, calendar: appModel.settings.calendar))")
                            .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
                .swipeActions {
                    Button(rule.isPaused ? "Resume" : "Pause") {
                        rule.isPaused.toggle()
                        try? context.save()
                        Task { await refreshNotifications() }
                    }
                }
            }
        }
        .navigationTitle("Recurring")
        .toolbar { Button { showEditor = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add schedule") }
        .sheet(isPresented: $showEditor) { NavigationStack { RecurringEditorView(ruleID: nil) } }
        .moneyStalkerDestinations()
    }

    private func refreshNotifications() async {
        _ = (try? context.fetch(FetchDescriptor<Debt>())) ?? []
        await NotificationScheduler.reconcile(context: context, settings: appModel.settings)
    }
}

struct RecurringEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var rules: [RecurringRule]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var debts: [Debt]
    @Query private var goals: [SavingsGoal]
    var ruleID: UUID?
    @State private var name = ""
    @State private var type: TransactionType = .expense
    @State private var amount = ""
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var interval = 1
    @State private var start = Date()
    @State private var hasEnd = false
    @State private var end = Date()
    @State private var accountID: UUID?
    @State private var counterID: UUID?
    @State private var categoryID: UUID?
    @State private var notes = ""
    @State private var reminder = false
    @State private var lead = 60
    @State private var debtID: UUID?
    @State private var goalID: UUID?
    @State private var loaded = false
    @State private var error: String?
    @State private var confirmDelete = false

    private var rule: RecurringRule? { rules.first { $0.id == ruleID } }

    var body: some View {
        Form {
            TextField("Name", text: $name)
            Picker("Type", selection: $type) {
                Text("Expense").tag(TransactionType.expense)
                Text("Income").tag(TransactionType.income)
                Text("Transfer").tag(TransactionType.transfer)
                Text("Loan repayment").tag(TransactionType.principal)
            }
            MoneyPadField(text: $amount, placeholder: "Amount", locale: appModel.settings.formattingLocale)
            Picker("Repeats", selection: $frequency) { ForEach(RecurrenceFrequency.allCases) { Text($0.title).tag($0) } }
            Stepper("Every \(interval)", value: $interval, in: 1...36)
            DatePicker("Starts", selection: $start)
            Toggle("End date", isOn: $hasEnd)
            if hasEnd { DatePicker("Ends", selection: $end) }
            Picker("Account", selection: $accountID) {
                Text("Choose").tag(Optional<UUID>.none)
                ForEach(accounts.filter { !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) }
            }
            if type == .transfer {
                Picker("To", selection: $counterID) {
                    Text("Choose").tag(Optional<UUID>.none)
                    ForEach(accounts.filter { !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Goal", selection: $goalID) {
                    Text("No goal").tag(Optional<UUID>.none)
                    ForEach(goals) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            if type == .income || type == .expense {
                Picker("Category", selection: $categoryID) {
                    Text("Choose").tag(Optional<UUID>.none)
                    ForEach(categories.filter { $0.kind == (type == .income ? .income : .expense) && !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            if type == .principal {
                Picker("Debt", selection: $debtID) {
                    Text("Choose").tag(Optional<UUID>.none)
                    ForEach(debts) { Text($0.person).tag(Optional($0.id)) }
                }
            }
            TextField("Notes", text: $notes)
            Toggle("Reminder", isOn: $reminder)
            if reminder { Stepper("\(lead) minutes before", value: $lead, in: 0...10080, step: 30) }
            if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            if rule != nil { Button("Delete schedule", role: .destructive) { confirmDelete = true } }
        }
        .navigationTitle(rule == nil ? "New schedule" : "Schedule")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
        }
        .onAppear(perform: load)
        .moneyStalkerConfirmation(isPresented: $confirmDelete, title: "Delete this schedule?", message: "Transactions already posted stay in your history.", confirmTitle: "Delete") {
            if let rule { context.delete(rule); try? context.save(); dismiss() }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let rule else { return }
        name = rule.name
        type = rule.type == .principal ? .principal : rule.type
        amount = MoneyText.plain(minor: rule.amountMinor, code: rule.currencyCode)
        frequency = rule.frequency
        interval = rule.interval
        start = rule.startDate
        hasEnd = rule.endDate != nil
        end = rule.endDate ?? .now
        accountID = rule.account?.id
        counterID = rule.counterAccount?.id
        categoryID = rule.category?.id
        notes = rule.notes
        reminder = rule.reminderEnabled
        lead = rule.reminderLeadMinutes
        debtID = rule.linkedDebtID
        goalID = rule.linkedGoalID
    }

    private func save() {
        guard let account = accounts.first(where: { $0.id == accountID }) else { error = "Choose an account."; return }
        guard let minor = MoneyInput.minorUnits(from: amount, currencyCode: account.currencyCode, locale: appModel.settings.formattingLocale), minor > 0 else {
            error = "Enter an amount greater than zero."; return
        }
        let category = categories.first { $0.id == categoryID }
        let counter = accounts.first { $0.id == counterID }
        if type == .transfer && counter == nil { error = "Choose the destination account."; return }
        if (type == .income || type == .expense) && category == nil { error = "Choose a category."; return }
        let linkage: TransactionLinkage = type == .principal ? .debtRepayment : (goalID == nil ? .none : .goalFunding)
        let direction: PrincipalDirection = .outbound
        if let rule {
            rule.name = name
            rule.amountMinor = minor
            rule.type = type == .principal ? .principal : type
            rule.linkage = linkage
            rule.principalDirection = direction
            rule.currencyCode = account.currencyCode
            rule.destinationCurrencyCode = counter?.currencyCode ?? account.currencyCode
            rule.frequency = frequency
            rule.interval = interval
            rule.startDate = start
            rule.endDate = hasEnd ? end : nil
            rule.nextOccurrence = start
            rule.notes = notes
            rule.reminderEnabled = reminder
            rule.reminderLeadMinutes = lead
            rule.account = account
            rule.counterAccount = counter
            rule.category = category
            rule.linkedDebtID = debtID
            rule.linkedGoalID = goalID
            rule.updatedAt = .now
        } else {
            let created = RecurringRule(name: name.isEmpty ? type.title : name, amountMinor: minor, type: type == .principal ? .principal : type, linkage: linkage, principalDirection: direction, currencyCode: account.currencyCode, destinationCurrencyCode: counter?.currencyCode ?? account.currencyCode, frequency: frequency, interval: interval, startDate: start, endDate: hasEnd ? end : nil, nextOccurrence: start, notes: notes, reminderEnabled: reminder, reminderLeadMinutes: lead, linkedDebtID: debtID, linkedGoalID: goalID)
            context.insert(created)
            created.account = account
            created.counterAccount = counter
            created.category = category
        }
        do {
            try context.save()
            try RecurringProcessor.process(context: context, now: .now, calendar: appModel.settings.calendar)
            Task { await NotificationScheduler.reconcile(context: context, settings: appModel.settings) }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
