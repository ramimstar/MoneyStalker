import SwiftData
import SwiftUI

struct DebtsView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \Debt.createdAt, order: .reverse) private var debts: [Debt]
    @Query private var repayments: [DebtRepayment]
    @State private var showEditor = false

    var body: some View {
        List {
            Section {
                Text("Loan proceeds and principal repayments change account balances, but they are not ordinary income or expenses. Interest is recorded separately.")
                    .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
            }
            ForEach(summaries) { item in
                NavigationLink(value: AppRoute.debt(item.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.person).font(.headline)
                        Text("\(item.direction.title) · \(item.status.title)")
                            .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                        Text("Outstanding \(MoneyText.string(minor: item.outstandingMinor, code: item.currencyCode, locale: appModel.settings.formattingLocale))")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("Debts")
        .toolbar { Button { showEditor = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add debt") }
        .sheet(isPresented: $showEditor) { DebtEditorView() }
        .moneyStalkerDestinations()
        .overlay { if debts.isEmpty { EmptyStateView(systemImage: "person.2", title: "No debts", message: "Track money you borrowed or lent. Money Stalker will not treat the principal as income or an expense.", actionTitle: "Add debt") { showEditor = true } } }
    }

    private var summaries: [DebtSummary] {
        debts.map { DebtMath.summary(debt: $0.snapshot, repayments: repayments.map(\.snapshot)) }
    }
}

struct DebtDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query private var debts: [Debt]
    var debtID: UUID
    @State private var showRepay = false
    @State private var showInterest = false
    @State private var confirm = false

    private var debt: Debt? { debts.first { $0.id == debtID } }

    var body: some View {
        Group {
            if let debt {
                let summary = DebtMath.summary(debt: debt.snapshot, repayments: debt.repayments.map(\.snapshot))
                List {
                    Section {
                        LabeledContent("Outstanding", value: MoneyText.string(minor: summary.outstandingMinor, code: summary.currencyCode, locale: appModel.settings.formattingLocale))
                        LabeledContent("Original", value: MoneyText.string(minor: summary.originalMinor, code: summary.currencyCode, locale: appModel.settings.formattingLocale))
                        LabeledContent("Status", value: summary.status.title)
                        if let due = debt.dueDate {
                            LabeledContent("Due", value: DateFormatting.string(from: due, style: appModel.settings.dateStyle, locale: appModel.settings.formattingLocale, calendar: appModel.settings.calendar))
                        }
                        if !debt.interestRateText.isEmpty { LabeledContent("Interest rate", value: debt.interestRateText + "%") }
                        Text("Interest is not added automatically.").font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                    }
                    Section("Principal repayments") {
                        if debt.repayments.isEmpty { Text("None yet.").foregroundStyle(Color.moneyStalkerSlate) }
                        ForEach(debt.repayments.sorted { $0.date > $1.date }) { repayment in
                            Text(MoneyText.string(minor: repayment.amountMinor, code: debt.currencyCode, locale: appModel.settings.formattingLocale))
                        }
                    }
                    Section {
                        Button("Record repayment") { showRepay = true }.disabled(summary.outstandingMinor == 0)
                        Button("Record interest") { showInterest = true }
                        Button("Delete debt", role: .destructive) { confirm = true }
                    }
                }
                .navigationTitle(debt.person)
                .sheet(isPresented: $showRepay) { DebtPaymentSheet(debt: debt, interest: false) }
                .sheet(isPresented: $showInterest) { DebtPaymentSheet(debt: debt, interest: true) }
                .moneyStalkerConfirmation(isPresented: $confirm, title: "Delete this debt?", message: "Linked principal, repayments, and interest records are removed so account balances return to where they were without this debt.", confirmTitle: "Delete") {
                    try? DebtWriter.delete(debt: debt, context: context)
                }
            } else {
                ContentUnavailableView("Debt unavailable", systemImage: "person.2")
            }
        }
    }
}

struct DebtEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var person = ""
    @State private var direction: DebtDirection = .borrowed
    @State private var amount = ""
    @State private var currency = "USD"
    @State private var accountID: UUID?
    @State private var hasDue = false
    @State private var due = Date()
    @State private var rate = ""
    @State private var notes = ""
    @State private var reminder = false
    @State private var date = Date()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Person or organization", text: $person)
                Picker("Direction", selection: $direction) { ForEach(DebtDirection.allCases) { Text($0.title).tag($0) } }
                MoneyPadField(text: $amount, placeholder: "Amount", locale: appModel.settings.formattingLocale)
                Picker("Currency", selection: $currency) { ForEach(CurrencyCatalog.common) { Text($0.code).tag($0.code) } }
                Picker("Account", selection: $accountID) {
                    Text("Do not move money").tag(Optional<UUID>.none)
                    ForEach(accounts.filter { !$0.isArchived }) { Text("\($0.name) · \($0.currencyCode)").tag(Optional($0.id)) }
                }
                DatePicker("Recorded on", selection: $date)
                Toggle("Due date", isOn: $hasDue)
                if hasDue { DatePicker("Due", selection: $due, displayedComponents: .date) }
                MoneyPadField(text: $rate, placeholder: "Interest rate % (optional)", locale: appModel.settings.formattingLocale)
                TextField("Notes", text: $notes)
                Toggle("Reminder on the due date", isOn: $reminder)
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle("New debt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear { currency = appModel.settings.currencyCode }
        }
    }

    private func save() {
        let account = accounts.first { $0.id == accountID }
        let code = account?.currencyCode ?? currency
        guard let minor = MoneyInput.minorUnits(from: amount, currencyCode: code, locale: appModel.settings.formattingLocale) else {
            error = "Enter an amount."; return
        }
        do {
            _ = try DebtWriter.create(person: person, direction: direction, amountMinor: minor, currencyCode: code, account: account, dueDate: hasDue ? due : nil, interestRateText: rate, notes: notes, reminder: reminder, date: date, context: context)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct DebtPaymentSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    var debt: Debt
    var interest: Bool
    @State private var amount = ""
    @State private var accountID: UUID?
    @State private var categoryID: UUID?
    @State private var date = Date()
    @State private var notes = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                MoneyPadField(text: $amount, placeholder: "Amount", locale: appModel.settings.formattingLocale)
                Picker("Account", selection: $accountID) {
                    Text("Choose").tag(Optional<UUID>.none)
                    ForEach(accounts.filter { $0.currencyCode == debt.currencyCode && !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) }
                }
                if interest {
                    Picker("Category", selection: $categoryID) {
                        Text("Choose").tag(Optional<UUID>.none)
                        ForEach(categories.filter { $0.kind == (debt.direction == .borrowed ? .expense : .income) }) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                DatePicker("Date", selection: $date)
                TextField("Notes", text: $notes)
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle(interest ? "Interest" : "Repayment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        guard let account = accounts.first(where: { $0.id == accountID }) else { error = "Choose an account."; return }
        guard let minor = MoneyInput.minorUnits(from: amount, currencyCode: debt.currencyCode, locale: appModel.settings.formattingLocale) else {
            error = "Enter an amount."; return
        }
        do {
            if interest {
                guard let category = categories.first(where: { $0.id == categoryID }) else { error = "Choose a category."; return }
                try DebtWriter.recordInterest(debt: debt, amountMinor: minor, account: account, category: category, date: date, notes: notes, context: context)
            } else {
                try DebtWriter.repay(debt: debt, amountMinor: minor, account: account, date: date, notes: notes, context: context)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
