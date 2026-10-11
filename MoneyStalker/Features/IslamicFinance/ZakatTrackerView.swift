import PhotosUI
import SwiftData
import SwiftUI

struct ZakatTrackerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query(sort: \ZakatCalculationRecord.createdAt, order: .reverse) private var calculations: [ZakatCalculationRecord]
    @Query(sort: \CharityRecord.date, order: .reverse) private var records: [CharityRecord]
    @Query(sort: \CharityGoal.startDate, order: .reverse) private var goals: [CharityGoal]
    @State private var showPayment = false
    @State private var showGoal = false
    @State private var editingRecordID: UUID?
    @State private var editingGoalID: UUID?
    @State private var deleteRecord = false
    @State private var deleteGoal = false
    @State private var pendingRecordID: UUID?
    @State private var pendingGoalID: UUID?

    var body: some View {
        List {
            Section("Saved estimates") {
                if calculations.isEmpty {
                    Text("No estimate has been saved yet.")
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
                ForEach(calculations) { item in
                    let paidLater = paidToward(item)
                    NavigationLink(value: AppRoute.zakatEstimate(item.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.methodRaw == ZakatNisabMethod.gold.rawValue ? "Gold nisab" : "Silver nisab")
                                .font(.body.weight(.semibold))
                            Text("Estimated \(money(item.zakatDueMinor, item.currencyCode))")
                            Text("Recorded later \(money(paidLater, item.currencyCode)) · Still to record \(money(CharityMath.remainingAfterPayments(snapshotRemainingMinor: item.remainingMinor, laterPaymentsMinor: paidLater), item.currencyCode))")
                                .font(.caption)
                                .foregroundStyle(Color.moneyStalkerSlate)
                        }
                    }
                }
            }
            Section("Payments and sadaqah") {
                if records.isEmpty {
                    Text("Zakat payments and sadaqah you record will stay separate from ordinary expenses unless you link one you already saved.")
                        .font(.footnote)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.kindRaw.capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.moneyStalkerSlate)
                        Text(money(record.amountMinor, record.currencyCode))
                        if !record.recipient.isEmpty { Text(record.recipient).font(.caption) }
                        if record.transactionID != nil {
                            Text("Linked to an existing expense. It is not counted again.")
                                .font(.caption2)
                                .foregroundStyle(Color.moneyStalkerSlate)
                        }
                    }
                    .swipeActions {
                        Button("Edit") { editingRecordID = record.id }.tint(Color.moneyStalkerPrimary)
                        Button("Delete", role: .destructive) {
                            pendingRecordID = record.id
                            deleteRecord = true
                        }
                    }
                    .accessibilityHint("Swipe for edit or delete")
                }
                Button("Record a payment or donation") { showPayment = true }
            }
            Section("Charity goals") {
                if goals.isEmpty {
                    Text("A goal tracks donations you record. It does not move account balances.")
                        .font(.footnote)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
                ForEach(goals) { goal in
                    let paid = CharityMath.progress(
                        amounts: records.filter { goal.donationKindRaw == "any" || $0.kindRaw == goal.donationKindRaw }.map { ($0.date, $0.amountMinor, $0.currencyCode) },
                        currencyCode: goal.currencyCode,
                        start: goal.startDate,
                        end: goal.endDate
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.name).font(.body.weight(.semibold))
                        Text("\(money(paid, goal.currencyCode)) of \(money(goal.targetMinor, goal.currencyCode))")
                            .font(.caption)
                            .foregroundStyle(Color.moneyStalkerSlate)
                        RangeFill(progress: goal.targetMinor > 0 ? min(1, Double(paid) / Double(goal.targetMinor)) : 0, tint: Color.moneyStalkerIncome, height: 6)
                    }
                    .swipeActions {
                        Button("Edit") { editingGoalID = goal.id }.tint(Color.moneyStalkerPrimary)
                        Button("Delete", role: .destructive) {
                            pendingGoalID = goal.id
                            deleteGoal = true
                        }
                    }
                }
                Button("Add a charity goal") { showGoal = true }
            }
        }
        .navigationTitle("Zakat and sadaqah")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPayment) { CharityPaymentSheet() }
        .sheet(isPresented: Binding(get: { editingRecordID != nil }, set: { if !$0 { editingRecordID = nil } })) {
            CharityPaymentSheet(existingID: editingRecordID)
        }
        .sheet(isPresented: $showGoal) { CharityGoalSheet() }
        .sheet(isPresented: Binding(get: { editingGoalID != nil }, set: { if !$0 { editingGoalID = nil } })) {
            CharityGoalSheet(existingID: editingGoalID)
        }
        .moneyStalkerConfirmation(isPresented: $deleteRecord, title: "Delete this donation?", message: "The donation record is removed. A linked expense stays in your ledger.", confirmTitle: "Delete") {
            if let pendingRecordID, let record = records.first(where: { $0.id == pendingRecordID }) {
                context.delete(record)
                try? context.save()
            }
        }
        .moneyStalkerConfirmation(isPresented: $deleteGoal, title: "Delete this charity goal?", message: "The goal is removed. Donation records stay.", confirmTitle: "Delete") {
            if let pendingGoalID, let goal = goals.first(where: { $0.id == pendingGoalID }) {
                context.delete(goal)
                try? context.save()
            }
        }
    }

    private func money(_ minor: Int64, _ code: String) -> String {
        MoneyText.string(minor: minor, code: code, locale: appModel.settings.formattingLocale)
    }

    private func paidToward(_ item: ZakatCalculationRecord) -> Int64 {
        records.filter { $0.calculationID == item.id && $0.kindRaw == "zakat" }.reduce(0) { $0 + max(0, $1.amountMinor) }
    }
}

struct ZakatEstimateDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var calculations: [ZakatCalculationRecord]
    @Query private var records: [CharityRecord]
    var calculationID: UUID
    @State private var confirm = false

    private var record: ZakatCalculationRecord? { calculations.first { $0.id == calculationID } }

    var body: some View {
        Group {
            if let record {
                Form {
                    LabeledContent("Saved", value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Method", value: record.methodRaw == ZakatNisabMethod.gold.rawValue ? "Gold nisab" : "Silver nisab")
                    LabeledContent("Engine", value: "Version \(record.engineVersion)")
                    LabeledContent("Eligible assets", value: money(record.eligibleAssetsMinor, record))
                    LabeledContent("Deductions", value: money(record.deductionsMinor, record))
                    LabeledContent("Net wealth", value: money(record.netWealthMinor, record))
                    LabeledContent("Nisab", value: record.nisabKnown ? money(record.nisabMinor, record) : "Not priced")
                    LabeledContent("Estimated zakat", value: money(record.zakatDueMinor, record))
                    LabeledContent("Remaining on the snapshot", value: money(record.remainingMinor, record))
                    let paidLater = records.filter { $0.calculationID == record.id && $0.kindRaw == "zakat" }.reduce(Int64(0)) { $0 + max(0, $1.amountMinor) }
                    LabeledContent("Zakat recorded later", value: money(paidLater, record))
                    LabeledContent("Still to record", value: money(CharityMath.remainingAfterPayments(snapshotRemainingMinor: record.remainingMinor, laterPaymentsMinor: paidLater), record))
                    if let date = record.hawlDate {
                        LabeledContent("Hawl date", value: date.formatted(date: .abbreviated, time: .omitted))
                    }
                    if !record.goldPriceSource.isEmpty {
                        LabeledContent("Gold price source", value: record.goldPriceSource)
                    }
                    if !record.silverPriceSource.isEmpty {
                        LabeledContent("Silver price source", value: record.silverPriceSource)
                    }
                    Section("Notes saved with this estimate") {
                        ForEach(record.notes, id: \.self) { Text($0).font(.footnote) }
                    }
                    Button("Delete estimate", role: .destructive) { confirm = true }
                }
                .moneyStalkerConfirmation(isPresented: $confirm, title: "Delete this estimate?", message: "The saved snapshot will be removed. Linked donation notes stay unless you delete them too.", confirmTitle: "Delete") {
                    context.delete(record)
                    try? context.save()
                    dismiss()
                }
            } else {
                Text("This estimate is no longer on this iPhone.")
            }
        }
        .navigationTitle("Saved estimate")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func money(_ minor: Int64, _ record: ZakatCalculationRecord) -> String {
        MoneyText.string(minor: minor, code: record.currencyCode, locale: appModel.settings.formattingLocale)
    }
}

struct CharityPaymentSheet: View {
    var existingID: UUID? = nil
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LedgerTransaction.date, order: .reverse) private var transactions: [LedgerTransaction]
    @Query private var records: [CharityRecord]
    @Query private var calculations: [ZakatCalculationRecord]
    @State private var kind = "sadaqah"
    @State private var amount = ""
    @State private var date = Date()
    @State private var recipient = ""
    @State private var notes = ""
    @State private var link = false
    @State private var transactionID: UUID?
    @State private var calculationID: UUID?
    @State private var error: String?
    @State private var photo: PhotosPickerItem?
    @State private var receipt: Data?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Zakat").tag("zakat")
                    Text("Sadaqah").tag("sadaqah")
                    Text("Other charity").tag("other")
                }
                MoneyPadField(text: $amount, placeholder: "Amount", locale: appModel.settings.formattingLocale)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Recipient or organization", text: $recipient)
                TextField("Notes", text: $notes)
                PhotosPicker(selection: $photo, matching: .images) {
                    Label(receipt == nil ? "Add receipt" : "Replace receipt", systemImage: "photo")
                }
                .accessibilityLabel("Add receipt photo")
                if let receipt, let image = UIImage(data: receipt) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160)
                }
                if kind == "zakat" {
                    Picker("Saved estimate", selection: $calculationID) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(calculations) { item in
                            Text(item.createdAt.formatted(date: .abbreviated, time: .omitted)).tag(Optional(item.id))
                        }
                    }
                }
                Toggle("Link an existing expense", isOn: $link)
                if link {
                    Picker("Expense", selection: $transactionID) {
                        Text("Choose").tag(Optional<UUID>.none)
                        ForEach(transactions.filter { $0.type == .expense }) { item in
                            Text(item.notes.isEmpty ? item.category?.name ?? "Expense" : item.notes).tag(Optional(item.id))
                        }
                    }
                    Text("Linking uses the expense you already saved. It does not add a second expense.")
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle(existingID == nil ? "Donation" : "Edit donation")
            .onAppear(perform: loadExisting)
            .onChange(of: photo) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        receipt = data
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        let code = appModel.settings.currencyCode
        guard let minor = MoneyInput.minorUnits(from: amount, currencyCode: code, locale: appModel.settings.formattingLocale), minor > 0 else {
            error = "Enter an amount greater than zero."
            return
        }
        let current = records.first { $0.id == existingID }
        if link {
            guard let transactionID else { error = "Choose the expense to link."; return }
            let used = records.compactMap(\.transactionID).filter { $0 != current?.transactionID }
            guard CharityMath.canLink(transactionID: transactionID, existingTransactionIDs: used) else {
                error = "That expense is already linked to a donation."
                return
            }
        }
        let linkedCalculation = kind == "zakat" ? calculationID : nil
        let linkedTransaction = link ? transactionID : nil
        if let current {
            current.kindRaw = kind
            current.amountMinor = minor
            current.currencyCode = code
            current.date = date
            current.recipient = recipient
            current.notes = notes
            current.transactionID = linkedTransaction
            current.calculationID = linkedCalculation
            if let receipt { current.receiptImage = receipt }
        } else {
            context.insert(CharityRecord(kindRaw: kind, amountMinor: minor, currencyCode: code, date: date, recipient: recipient, notes: notes, receiptImage: receipt, transactionID: linkedTransaction, calculationID: linkedCalculation))
        }
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }

    private func loadExisting() {
        guard !loaded, let existingID, let current = records.first(where: { $0.id == existingID }) else { return }
        loaded = true
        kind = current.kindRaw
        amount = MoneyText.plain(minor: current.amountMinor, code: current.currencyCode)
        date = current.date
        recipient = current.recipient
        notes = current.notes
        link = current.transactionID != nil
        transactionID = current.transactionID
        calculationID = current.calculationID
        receipt = current.receiptImage
    }
}

struct CharityGoalSheet: View {
    var existingID: UUID? = nil
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [CharityGoal]
    @State private var name = ""
    @State private var cadence = "monthly"
    @State private var kind = "sadaqah"
    @State private var amount = ""
    @State private var start = Date()
    @State private var hasEnd = false
    @State private var end = Date()
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Repeats", selection: $cadence) {
                    Text("Weekly").tag("weekly")
                    Text("Monthly").tag("monthly")
                    Text("Ramadan").tag("ramadan")
                    Text("Custom").tag("custom")
                }
                Picker("Counts", selection: $kind) {
                    Text("Sadaqah").tag("sadaqah")
                    Text("Zakat").tag("zakat")
                    Text("Other charity").tag("other")
                    Text("Any recorded donation").tag("any")
                }
                MoneyPadField(text: $amount, placeholder: "Target", locale: appModel.settings.formattingLocale)
                DatePicker("Starts", selection: $start, displayedComponents: .date)
                Toggle("End date", isOn: $hasEnd)
                if hasEnd { DatePicker("Ends", selection: $end, displayedComponents: .date) }
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle(existingID == nil ? "Charity goal" : "Edit charity goal")
            .onAppear(perform: loadExisting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        let code = appModel.settings.currencyCode
        guard let minor = MoneyInput.minorUnits(from: amount, currencyCode: code, locale: appModel.settings.formattingLocale), minor > 0 else {
            error = "Enter a target greater than zero."
            return
        }
        let title = name.isEmpty ? "Charity goal" : name
        let finish = hasEnd ? end : nil
        if let current = goals.first(where: { $0.id == existingID }) {
            current.name = title
            current.cadenceRaw = cadence
            current.donationKindRaw = kind
            current.targetMinor = minor
            current.currencyCode = code
            current.startDate = start
            current.endDate = finish
        } else {
            context.insert(CharityGoal(name: title, cadenceRaw: cadence, donationKindRaw: kind, targetMinor: minor, currencyCode: code, startDate: start, endDate: finish))
        }
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }

    private func loadExisting() {
        guard !loaded, let existingID, let current = goals.first(where: { $0.id == existingID }) else { return }
        loaded = true
        name = current.name
        cadence = current.cadenceRaw
        kind = current.donationKindRaw
        amount = MoneyText.plain(minor: current.targetMinor, code: current.currencyCode)
        start = current.startDate
        hasEnd = current.endDate != nil
        end = current.endDate ?? current.startDate
    }
}
