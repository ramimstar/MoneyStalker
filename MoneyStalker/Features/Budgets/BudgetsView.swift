import SwiftData
import SwiftUI
import UIKit

struct BudgetsView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \Budget.createdAt) private var budgets: [Budget]
    @Query private var transactions: [LedgerTransaction]
    @Query private var categories: [Category]
    @State private var showEditor = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if budgets.isEmpty {
                    EmptyStateView(systemImage: "chart.pie", title: "No budgets", message: "A budget compares a spending limit with recorded expenses. Income and transfers are ignored.", actionTitle: "Create budget") { showEditor = true }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(statuses) { status in
                                NavigationLink(value: AppRoute.budget(status.id)) {
                                    budgetCard(status)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .moneyStalkerHidesTabBar(.budgets)
                }
            }
            .moneyStalkerScreen()
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add budget")
                }
            }
            .sheet(isPresented: $showEditor) { BudgetEditorView(budget: nil) }
            .moneyStalkerDestinations()
            .onChange(of: appModel.notificationDestination) { _, route in
                guard let route else { return }
                if case .budget = route {
                    path.append(route)
                    appModel.notificationDestination = nil
                }
            }
        }
    }

    private func budgetCard(_ status: BudgetStatus) -> some View {
        let category = budgets.first { $0.id == status.id }?.category
        let index = statuses.firstIndex { $0.id == status.id } ?? 0
        return BudgetProgressCard(
            status: status,
            locale: appModel.settings.formattingLocale,
            systemName: category?.icon ?? "chart.pie.fill",
            colorHex: category?.colorHex ?? "1B7F45",
            graph: CardGraphKind.at(index)
        )
    }

    private var statuses: [BudgetStatus] {
        budgets.filter { !$0.isArchived }.map {
            BudgetEngine.status(budget: $0.snapshot, transactions: transactions.map(\.snapshot), categories: categories.map(\.snapshot), now: .now, calendar: appModel.settings.calendar)
        }
    }
}

#Preview("Budgets") {
    MoneyStalkerPreview.host { BudgetsView() }
}

struct BudgetDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query private var budgets: [Budget]
    @Query private var transactions: [LedgerTransaction]
    @Query private var categories: [Category]
    var budgetID: UUID
    @State private var showEditor = false
    @State private var confirm = false

    private var budget: Budget? { budgets.first { $0.id == budgetID } }

    var body: some View {
        Group {
            if let budget {
                let status = BudgetEngine.status(budget: budget.snapshot, transactions: transactions.map(\.snapshot), categories: categories.map(\.snapshot), now: .now, calendar: appModel.settings.calendar)
                List {
                    Section {
                        BudgetProgressCard(
                            status: status,
                            locale: appModel.settings.formattingLocale,
                            systemName: budget.category?.icon ?? "chart.pie.fill",
                            colorHex: budget.category?.colorHex ?? "1B7F45",
                            graph: .ring
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    Section("Limit") {
                        LabeledContent("Limit", value: MoneyText.string(minor: status.limitMinor, code: status.currencyCode, locale: appModel.settings.formattingLocale))
                        LabeledContent("Available", value: MoneyText.string(minor: status.availableMinor, code: status.currencyCode, locale: appModel.settings.formattingLocale))
                        if budget.rollover { Text("Unspent and overspent amounts carry into the next period.") .font(.caption).foregroundStyle(Color.moneyStalkerSlate) }
                    }
                    Section {
                        Button("Edit") { showEditor = true }
                        Button(budget.isArchived ? "Unarchive" : "Archive") { budget.isArchived.toggle(); try? context.save() }
                        Button("Delete", role: .destructive) { confirm = true }
                    }
                }
                .navigationTitle(budget.name)
                .sheet(isPresented: $showEditor) { BudgetEditorView(budget: budget) }
                .moneyStalkerConfirmation(isPresented: $confirm, title: "Delete budget?", message: "Transactions stay. Only this limit is removed.", confirmTitle: "Delete") {
                    context.delete(budget)
                    try? context.save()
                }
            } else {
                ContentUnavailableView("Budget unavailable", systemImage: "chart.pie")
            }
        }
    }
}

struct BudgetEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    var budget: Budget?
    @State private var name = ""
    @State private var kind: BudgetPeriodKind = .monthly
    @State private var amount = ""
    @State private var currency = "USD"
    @State private var start = Date()
    @State private var end = Date()
    @State private var categoryID: UUID?
    @State private var warning = 0.8
    @State private var rollover = false
    @State private var loaded = false
    @State private var error: String?
    @State private var amountFocused = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Period", selection: $kind) { ForEach(BudgetPeriodKind.allCases) { Text($0.title).tag($0) } }
                MoneyPadField(text: $amount, placeholder: "Spending limit", locale: appModel.settings.formattingLocale, showsDone: false, isFocused: $amountFocused)
                Picker("Currency", selection: $currency) { ForEach(CurrencyCatalog.common) { Text($0.code).tag($0.code) } }
                Picker("Category", selection: $categoryID) {
                    Text("Overall spending").tag(Optional<UUID>.none)
                    ForEach(categories.filter { $0.kind == .expense && !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) }
                }
                DatePicker("Starts", selection: $start, displayedComponents: .date)
                if kind == .custom { DatePicker("Ends", selection: $end, displayedComponents: .date) }
                Toggle("Roll unused amount forward", isOn: $rollover).disabled(kind == .custom)
                VStack(alignment: .leading) {
                    Text("Warn at \(Int(warning * 100))%")
                    Slider(value: $warning, in: 0.5...0.95, step: 0.05)
                }
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle(budget == nil ? "New budget" : "Edit budget")
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
                if let budget {
                    name = budget.name
                    kind = budget.kind
                    amount = MoneyText.plain(minor: budget.limitMinor, code: budget.currencyCode)
                    currency = budget.currencyCode
                    start = budget.startDate
                    end = budget.endDate ?? .now
                    categoryID = budget.category?.id
                    warning = budget.warningThreshold
                    rollover = budget.rollover
                }
            }
        }
    }

    private func save() {
        guard let minor = MoneyInput.minorUnits(from: amount, currencyCode: currency, locale: appModel.settings.formattingLocale), minor > 0 else {
            error = "Enter a spending limit greater than zero."
            return
        }
        let category = categories.first { $0.id == categoryID }
        if let budget {
            budget.name = name.isEmpty ? "Budget" : name
            budget.kind = kind
            budget.limitMinor = minor
            budget.currencyCode = currency
            budget.startDate = start
            budget.endDate = kind == .custom ? end : nil
            budget.warningThreshold = warning
            budget.rollover = kind == .custom ? false : rollover
            budget.category = category
        } else {
            let created = Budget(name: name.isEmpty ? "Budget" : name, kind: kind, limitMinor: minor, currencyCode: currency, startDate: start, endDate: kind == .custom ? end : nil, warningThreshold: warning, rollover: kind == .custom ? false : rollover, category: category)
            context.insert(created)
        }
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }
}
