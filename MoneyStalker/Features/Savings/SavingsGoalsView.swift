import SwiftData
import SwiftUI
import UIKit

struct SavingsGoalsView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var contributions: [SavingsContribution]
    @State private var showEditor = false

    var body: some View {
        List {
            ForEach(progress) { item in
                NavigationLink(value: AppRoute.goal(item.id)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.headline)
                        RangeFill(progress: min(1, Double(item.basisPoints) / 10_000), tint: Color.moneyStalkerPrimary, height: 6)
                        Text("\(MoneyText.string(minor: item.currentMinor, code: item.currencyCode, locale: appModel.settings.formattingLocale)) of \(MoneyText.string(minor: item.targetMinor, code: item.currencyCode, locale: appModel.settings.formattingLocale))")
                            .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
            }
        }
        .navigationTitle("Savings goals")
        .toolbar { Button { showEditor = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add goal") }
        .sheet(isPresented: $showEditor) { GoalEditorView(goal: nil) }
        .moneyStalkerDestinations()
        .overlay {
            if goals.isEmpty { EmptyStateView(systemImage: "flag", title: "No goals", message: "Track a target separately from income. A transfer contribution moves money without counting it as income.", actionTitle: "Add goal") { showEditor = true } }
        }
    }

    private var progress: [GoalProgress] { goals.map { GoalMath.progress(goal: $0.snapshot, contributions: contributions.map(\.snapshot)) } }
}

struct GoalDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query private var goals: [SavingsGoal]
    @Query private var contributions: [SavingsContribution]
    var goalID: UUID
    @State private var showAdd = false
    @State private var showEdit = false
    @State private var confirm = false

    private var goal: SavingsGoal? { goals.first { $0.id == goalID } }

    var body: some View {
        Group {
            if let goal {
                let progress = GoalMath.progress(goal: goal.snapshot, contributions: contributions.map(\.snapshot))
                List {
                    Section {
                        Text(MoneyText.percent(basisPoints: progress.basisPoints)).font(.largeTitle.weight(.semibold))
                        RangeFill(progress: min(1, Double(progress.basisPoints) / 10_000), tint: Color.moneyStalkerPrimary, height: 6)
                        Text("\(MoneyText.string(minor: progress.remainingMinor, code: progress.currencyCode, locale: appModel.settings.formattingLocale)) remaining")
                            .foregroundStyle(Color.moneyStalkerSlate)
                        if progress.isComplete { Text("Target reached.").foregroundStyle(Color.moneyStalkerIncome) }
                    }
                    Section("Contributions") {
                        ForEach(goal.contributions.sorted { $0.date > $1.date }) { contribution in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(MoneyText.string(minor: contribution.amountMinor, code: goal.currencyCode, locale: appModel.settings.formattingLocale))
                                    Text(contribution.transaction == nil ? "Recorded only" : "Linked transfer")
                                        .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                                }
                                Spacer()
                                Button("Delete", role: .destructive) {
                                    try? GoalWriter.deleteContribution(contribution, context: context)
                                }
                                .font(.caption)
                            }
                        }
                    }
                    Section {
                        Button("Add contribution") { showAdd = true }
                        Button("Edit") { showEdit = true }
                        Button("Delete goal", role: .destructive) { confirm = true }
                    }
                }
                .navigationTitle(goal.name)
                .sheet(isPresented: $showAdd) { ContributionSheet(goal: goal) }
                .sheet(isPresented: $showEdit) { GoalEditorView(goal: goal) }
                .moneyStalkerConfirmation(isPresented: $confirm, title: "Delete this goal?", message: "Contribution history is removed. Linked transfers stay in your accounts because the money really moved. Delete a contribution itself if you also want to reverse that transfer.", confirmTitle: "Delete goal") {
                    try? GoalWriter.deleteGoal(goal, context: context)
                }
            } else {
                ContentUnavailableView("Goal unavailable", systemImage: "flag")
            }
        }
    }
}

struct GoalEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    var goal: SavingsGoal?
    @State private var name = ""
    @State private var amount = ""
    @State private var currency = "USD"
    @State private var hasDate = false
    @State private var date = Date()
    @State private var accountID: UUID?
    @State private var notes = ""
    @State private var loaded = false
    @State private var error: String?
    @State private var amountFocused = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                MoneyPadField(text: $amount, placeholder: "Target", locale: appModel.settings.formattingLocale, showsDone: false, isFocused: $amountFocused)
                Picker("Currency", selection: $currency) { ForEach(CurrencyCatalog.common) { Text($0.code).tag($0.code) } }
                Toggle("Target date", isOn: $hasDate)
                if hasDate { DatePicker("Date", selection: $date, displayedComponents: .date) }
                Picker("Linked account", selection: $accountID) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
                }
                TextField("Notes", text: $notes)
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle(goal == nil ? "New goal" : "Edit goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .overlay(alignment: .bottom) {
                if amountFocused {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(Color.moneyStalkerOnHero)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color.moneyStalkerPrimary, in: Capsule())
                    }
                    .padding(.bottom, 20)
                    .accessibilityLabel("Done")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                currency = appModel.settings.currencyCode
                if let goal {
                    name = goal.name
                    amount = MoneyText.plain(minor: goal.targetMinor, code: goal.currencyCode)
                    currency = goal.currencyCode
                    hasDate = goal.targetDate != nil
                    date = goal.targetDate ?? .now
                    accountID = goal.linkedAccount?.id
                    notes = goal.notes
                }
            }
        }
    }

    private func save() {
        guard let minor = MoneyInput.minorUnits(from: amount, currencyCode: currency, locale: appModel.settings.formattingLocale), minor > 0 else {
            error = "Enter a target greater than zero."; return
        }
        let account = accounts.first { $0.id == accountID }
        if let goal {
            goal.name = name.isEmpty ? "Goal" : name
            goal.targetMinor = minor
            goal.currencyCode = currency
            goal.targetDate = hasDate ? date : nil
            goal.linkedAccount = account
            goal.notes = notes
        } else {
            let created = SavingsGoal(name: name.isEmpty ? "Goal" : name, targetMinor: minor, currencyCode: currency, targetDate: hasDate ? date : nil, notes: notes)
            context.insert(created)
            created.linkedAccount = account
        }
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }
}

struct ContributionSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    var goal: SavingsGoal
    @State private var amount = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var moveMoney = false
    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                MoneyPadField(text: $amount, placeholder: "Amount", locale: appModel.settings.formattingLocale)
                DatePicker("Date", selection: $date)
                Toggle("Move money between accounts", isOn: $moveMoney)
                if moveMoney {
                    Picker("From", selection: $fromID) {
                        Text("Choose").tag(Optional<UUID>.none)
                        ForEach(accounts.filter { $0.currencyCode == goal.currencyCode }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("To", selection: $toID) {
                        Text("Choose").tag(Optional<UUID>.none)
                        ForEach(accounts.filter { $0.currencyCode == goal.currencyCode }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Text("This creates a transfer. It is not income.").font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                } else {
                    Text("Record only if the money is already in the right account. This does not change balances.").font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                }
                TextField("Notes", text: $notes)
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle("Contribution")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        guard let minor = MoneyInput.minorUnits(from: amount, currencyCode: goal.currencyCode, locale: appModel.settings.formattingLocale) else {
            error = "Enter an amount."; return
        }
        do {
            try GoalWriter.addContribution(goal: goal, amountMinor: minor, date: date, notes: notes, from: moveMoney ? accounts.first { $0.id == fromID } : nil, to: moveMoney ? accounts.first { $0.id == toID } : nil, context: context)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
