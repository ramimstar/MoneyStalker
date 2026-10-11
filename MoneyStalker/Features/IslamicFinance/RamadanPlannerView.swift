import SwiftData
import SwiftUI

struct RamadanPlannerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query(sort: \RamadanPlan.hijriYear, order: .reverse) private var plans: [RamadanPlan]
    @State private var showNew = false

    var body: some View {
        List {
            if plans.isEmpty {
                Text("Set the Hijri year and the dates you are using. Ramadan is not given a fixed Gregorian date, because moon-sighting can differ.")
                    .font(.footnote)
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
            ForEach(plans) { plan in
                NavigationLink(value: AppRoute.ramadanPlan(plan.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hijri \(plan.hijriYear)").font(.body.weight(.semibold))
                        Text("\(plan.startDate.formatted(date: .abbreviated, time: .omitted)) – \(plan.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
            }
        }
        .navigationTitle("Ramadan planner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Add", systemImage: "plus") { showNew = true } }
        .sheet(isPresented: $showNew) { RamadanPlanSheet() }
    }
}

struct RamadanPlanSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var year = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Hijri year", text: $year)
                    .keyboardType(.numberPad)
                DatePicker("Starts", selection: $start, displayedComponents: .date)
                DatePicker("Ends", selection: $end, displayedComponents: .date)
                Text("Use the dates observed where you are. The app does not look up a moon-sighting calendar.")
                    .font(.footnote)
                    .foregroundStyle(Color.moneyStalkerSlate)
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle("Ramadan dates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        guard let hijri = Int(year), hijri > 0 else { error = "Enter the Hijri year."; return }
        guard end >= start else { error = "The end date has to be on or after the start date."; return }
        let plan = RamadanPlan(hijriYear: hijri, startDate: start, endDate: end, currencyCode: appModel.settings.currencyCode)
        context.insert(plan)
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }
}

struct RamadanPlanDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query private var plans: [RamadanPlan]
    @Query private var links: [RamadanLink]
    @Query private var transactions: [LedgerTransaction]
    var planID: UUID
    @State private var lineID: UUID?
    @State private var transactionID: UUID?
    @State private var error: String?
    @State private var confirm = false
    @State private var customName = ""

    private var plan: RamadanPlan? { plans.first { $0.id == planID } }

    var body: some View {
        Group {
            if let plan {
                let rows = plan.lines()
                let amounts = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0.amountMinor) })
                let planLinks = links.filter { $0.planID == plan.id }.map { (lineID: $0.lineID, transactionID: $0.transactionID) }
                Form {
                    Section {
                        Text("Planned amounts are targets. Actual amounts come only from expenses you link. Linking does not create another transaction, so budgets are not charged twice.")
                            .font(.footnote)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                    Section("Plan") {
                        ForEach(rows) { line in
                            let actual = RamadanMath.spent(lineID: line.id, links: planLinks, amounts: amounts)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(line.name).font(.body.weight(.semibold))
                                Text("Planned \(money(line.plannedMinor, plan)) · Actual \(money(actual, plan))")
                                    .font(.caption)
                                    .foregroundStyle(RamadanMath.warns(plannedMinor: line.plannedMinor, actualMinor: actual) ? Color.moneyStalkerExpense : Color.moneyStalkerSlate)
                                if line.plannedMinor > 0 {
                                    RangeFill(progress: min(1, Double(actual) / Double(line.plannedMinor)), tint: RamadanMath.warns(plannedMinor: line.plannedMinor, actualMinor: actual) ? Color.moneyStalkerExpense : Color.moneyStalkerIncome, height: 6)
                                }
                                MoneyPadField(text: plannedBinding(plan, line), placeholder: "Planned", locale: appModel.settings.formattingLocale)
                            }
                        }
                        let planned = rows.reduce(Int64(0)) { $0 + $1.plannedMinor }
                        let actual = rows.reduce(Int64(0)) { $0 + RamadanMath.spent(lineID: $1.id, links: planLinks, amounts: amounts) }
                        TextField("Custom line", text: $customName)
                        Button("Add line") { addLine(plan) }
                        LabeledContent("Planned total", value: money(planned, plan))
                        LabeledContent("Linked spending", value: money(actual, plan))
                        LabeledContent("Days in this plan", value: "\(dayCount(from: plan.startDate, to: plan.endDate))")
                        LabeledContent("Days elapsed", value: "\(elapsedDays(plan))")
                        RangeFill(progress: dayCount(from: plan.startDate, to: plan.endDate) > 0 ? min(1, Double(elapsedDays(plan)) / Double(dayCount(from: plan.startDate, to: plan.endDate))) : 0, tint: Color.moneyStalkerPrimary, height: 6)
                        if RamadanMath.warns(plannedMinor: planned, actualMinor: actual) {
                            Text("Linked spending is above the planned total.")
                                .font(.footnote)
                                .foregroundStyle(Color.moneyStalkerExpense)
                        }
                    }
                    Section("Savings target") {
                        MoneyPadField(text: savingsBinding(plan), placeholder: "Target", locale: appModel.settings.formattingLocale)
                    }
                    Section("Link an expense") {
                        Picker("Line", selection: $lineID) {
                            Text("Choose").tag(Optional<UUID>.none)
                            ForEach(rows) { Text($0.name).tag(Optional($0.id)) }
                        }
                        Picker("Expense in these dates", selection: $transactionID) {
                            Text("Choose").tag(Optional<UUID>.none)
                            ForEach(eligibleExpenses(plan)) { item in
                                Text(item.notes.isEmpty ? item.category?.name ?? "Expense" : item.notes).tag(Optional(item.id))
                            }
                        }
                        Button("Link") { link(plan) }
                        if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
                    }
                    Button("Delete this plan", role: .destructive) { confirm = true }
                }
                .moneyStalkerConfirmation(isPresented: $confirm, title: "Delete this Ramadan plan?", message: "The plan and its links are removed. The expenses themselves stay in your ledger.", confirmTitle: "Delete") {
                    for item in links where item.planID == plan.id { context.delete(item) }
                    context.delete(plan)
                    try? context.save()
                }
            } else {
                Text("This plan is no longer on this iPhone.")
            }
        }
        .navigationTitle("Ramadan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func money(_ minor: Int64, _ plan: RamadanPlan) -> String {
        MoneyText.string(minor: minor, code: plan.currencyCode, locale: appModel.settings.formattingLocale)
    }

    private func eligibleExpenses(_ plan: RamadanPlan) -> [LedgerTransaction] {
        transactions.filter { $0.type == .expense && RamadanMath.contains($0.date, start: plan.startDate, end: plan.endDate) }
    }

    private func plannedBinding(_ plan: RamadanPlan, _ line: RamadanLine) -> Binding<String> {
        Binding(get: {
            let current = plan.lines().first { $0.id == line.id }?.plannedMinor ?? 0
            return current == 0 ? "" : MoneyText.plain(minor: current, code: plan.currencyCode)
        }, set: { text in
            var rows = plan.lines()
            guard let index = rows.firstIndex(where: { $0.id == line.id }) else { return }
            rows[index].plannedMinor = MoneyInput.minorUnits(from: text, currencyCode: plan.currencyCode, locale: appModel.settings.formattingLocale) ?? 0
            plan.setLines(rows)
            try? context.save()
        })
    }

    private func savingsBinding(_ plan: RamadanPlan) -> Binding<String> {
        Binding(get: {
            plan.savingsTargetMinor == 0 ? "" : MoneyText.plain(minor: plan.savingsTargetMinor, code: plan.currencyCode)
        }, set: { text in
            plan.savingsTargetMinor = MoneyInput.minorUnits(from: text, currencyCode: plan.currencyCode, locale: appModel.settings.formattingLocale) ?? 0
            try? context.save()
        })
    }

    private func addLine(_ plan: RamadanPlan) {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { error = "Name the line before adding it."; return }
        var rows = plan.lines()
        rows.append(RamadanLine(id: UUID(), name: name, kind: "custom", plannedMinor: 0))
        plan.setLines(rows)
        customName = ""
        error = nil
        try? context.save()
    }

    private func dayCount(from start: Date, to end: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: end)).day ?? 0
        return max(1, days + 1)
    }

    private func elapsedDays(_ plan: RamadanPlan) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: plan.startDate)
        guard today >= start else { return 0 }
        let end = min(today, Calendar.current.startOfDay(for: plan.endDate))
        return dayCount(from: start, to: end)
    }

    private func link(_ plan: RamadanPlan) {
        guard let lineID, let transactionID else { error = "Choose a line and an expense."; return }
        let existing = links.filter { $0.planID == plan.id && $0.lineID == lineID }.map(\.transactionID)
        guard CharityMath.canLink(transactionID: transactionID, existingTransactionIDs: existing) else {
            error = "That expense is already linked to this line."
            return
        }
        context.insert(RamadanLink(planID: plan.id, lineID: lineID, transactionID: transactionID))
        do { try context.save(); error = nil } catch { self.error = error.localizedDescription }
    }
}
