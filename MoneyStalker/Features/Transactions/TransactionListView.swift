import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query(sort: \LedgerTransaction.date, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var filter = TransactionFilter()
    @State private var showFilter = false
    @State private var selection = Set<UUID>()
    @State private var editMode: EditMode = .inactive
    @State private var confirmDelete = false
    @State private var pendingDelete: LedgerTransaction?
    @State private var error: String?
    @State private var path = NavigationPath()
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                content
            }
            .moneyStalkerHidesTabBar(.transactions)
            .moneyStalkerScreen()
            .toolbar(.hidden, for: .navigationBar)
            .environment(\.editMode, $editMode)
            .moneyStalkerDestinations()
            .onChange(of: appModel.notificationDestination) { _, route in
                guard let route else { return }
                if case .transaction = route {
                    path.append(route)
                    appModel.notificationDestination = nil
                }
            }
            .sheet(isPresented: $showFilter) {
                TransactionFilterSheet(filter: $filter, accounts: accounts, categories: categories)
            }
            .moneyStalkerConfirmation(isPresented: $confirmDelete, title: "Delete transactions?", message: "This removes the selected records and updates every balance.", confirmTitle: "Delete") {
                deleteSelected()
            }
            .alert("Couldn't update", isPresented: errorShown) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            ReportsView(belowControls: searchField, aboveOverview: transactionsSection)
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "list.bullet.rectangle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerPrimary)
                .frame(width: 52, height: 52)
                .background(Color.moneyStalkerPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                Text("Review income, expenses, and reports")
                    .font(.subheadline)
                    .foregroundStyle(Color.moneyStalkerSlate)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Button { showFilter = true } label: {
                Image(systemName: filter.activeCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.moneyStalkerCard)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.moneyStalkerBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter transactions")
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.moneyStalkerSlate)
            TextField("Search notes, categories, tags", text: $filter.query)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.moneyStalkerCard)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.moneyStalkerBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(Capsule())
        .simultaneousGesture(TapGesture().onEnded { searchFocused = true })
        .onChange(of: searchFocused) { _, focused in
            if focused { SoftwareKeyboard.preferOnScreenKeypad() }
        }
    }

    @ViewBuilder private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transactions")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                Spacer()
                if editMode == .active {
                    if !selection.isEmpty {
                        Button("Delete", role: .destructive) { confirmDelete = true }
                            .font(.subheadline.weight(.semibold))
                    }
                    Button("Done") {
                        editMode = .inactive
                        selection.removeAll()
                    }
                    .font(.subheadline.weight(.semibold))
                } else if !visible.isEmpty {
                    Button("Select") { editMode = .active }
                        .font(.subheadline.weight(.semibold))
                }
            }
            if transactions.isEmpty {
                EmptyStateView(systemImage: "tray", title: "No transactions", message: "Income and expenses you save are listed here.", actionTitle: nil, action: nil)
            } else if visible.isEmpty {
                EmptyStateView(systemImage: "line.3.horizontal.decrease.circle", title: "No matches", message: "Nothing in the current search or filters.", actionTitle: nil, action: nil)
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DateFormatting.string(from: group.date, style: appModel.settings.dateStyle, locale: appModel.settings.formattingLocale, calendar: appModel.settings.calendar))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.moneyStalkerSlate)
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, transaction in
                                if editMode == .active {
                                    Button {
                                        if selection.contains(transaction.id) {
                                            selection.remove(transaction.id)
                                        } else {
                                            selection.insert(transaction.id)
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: selection.contains(transaction.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selection.contains(transaction.id) ? Color.moneyStalkerPrimary : Color.moneyStalkerSlate)
                                                .font(.title3)
                                            TransactionRow(transaction: transaction, locale: appModel.settings.formattingLocale)
                                                .padding(.vertical, 10)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink(value: AppRoute.transaction(transaction.id)) {
                                        TransactionRow(transaction: transaction, locale: appModel.settings.formattingLocale)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            pendingDelete = transaction
                                            selection = [transaction.id]
                                            confirmDelete = true
                                        }
                                    }
                                }
                                if index < group.items.count - 1 { Divider() }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background { MoneyStalkerMesh(style: .card, graph: .bars) }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
                    }
                }
            }
        }
    }

    private var visible: [LedgerTransaction] {
        let ordered = TransactionQuery.apply(transactions.map(\.snapshot), filter: filter, accounts: accounts.map(\.snapshot), categories: categories.map(\.snapshot))
        let lookup = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        return ordered.compactMap { lookup[$0.id] }
    }

    private var groups: [TransactionGroup] {
        let grouped = TransactionQuery.grouped(visible.map(\.snapshot), by: filter.grouping, calendar: appModel.settings.calendar)
        let lookup = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })
        return grouped.map { entry in
            TransactionGroup(date: entry.date, items: entry.items.compactMap { lookup[$0.id] })
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    private func deleteSelected() {
        let targets = transactions.filter { selection.contains($0.id) || $0.id == pendingDelete?.id }
        do {
            for transaction in targets {
                try TransactionWriter.delete(transaction, context: context)
            }
            selection.removeAll()
            pendingDelete = nil
            Task { await BudgetAlertService.evaluate(context: context, settings: appModel.settings) }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct TransactionGroup: Identifiable {
    var id: Date { date }
    var date: Date
    var items: [LedgerTransaction]
}

struct TransactionFilterSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: TransactionFilter
    var accounts: [Account]
    var categories: [Category]
    @State private var useDates = false
    @State private var start = Date()
    @State private var end = Date()
    @State private var minText = ""
    @State private var maxText = ""
    @State private var tag = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Sort", selection: $filter.sort) {
                    ForEach(TransactionSort.allCases) { Text($0.title).tag($0) }
                }
                Picker("Group", selection: $filter.grouping) {
                    ForEach(TransactionGrouping.allCases) { Text($0.title).tag($0) }
                }
                Picker("Type", selection: typeBinding) {
                    Text("Any").tag(Optional<TransactionType>.none)
                    ForEach(TransactionType.allCases) { Text($0.title).tag(Optional($0)) }
                }
                Picker("Account", selection: accountBinding) {
                    Text("Any").tag(Optional<UUID>.none)
                    ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Category", selection: categoryBinding) {
                    Text("Any").tag(Optional<UUID>.none)
                    ForEach(categories) { Text($0.name).tag(Optional($0.id)) }
                }
                MoneyPadField(text: $minText, placeholder: "Minimum amount", locale: appModel.settings.formattingLocale)
                MoneyPadField(text: $maxText, placeholder: "Maximum amount", locale: appModel.settings.formattingLocale)
                TextField("Tag", text: $tag)
                Toggle("Limit dates", isOn: $useDates)
                if useDates { DateRangePicker(start: $start, end: $end) }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Reset") { filter = TransactionFilter(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply") { apply(); dismiss() } }
            }
        }
    }

    private var typeBinding: Binding<TransactionType?> {
        Binding(get: { filter.type }, set: { filter.type = $0 })
    }
    private var accountBinding: Binding<UUID?> {
        Binding(get: { filter.accountID }, set: { filter.accountID = $0 })
    }
    private var categoryBinding: Binding<UUID?> {
        Binding(get: { filter.categoryID }, set: { filter.categoryID = $0 })
    }

    private func apply() {
        let code = appModel.settings.currencyCode
        let locale = appModel.settings.formattingLocale
        filter.minimumMinor = MoneyInput.minorUnits(from: minText, currencyCode: code, locale: locale)
        filter.maximumMinor = MoneyInput.minorUnits(from: maxText, currencyCode: code, locale: locale)
        filter.tag = tag
        filter.window = useDates ? DateWindow.covering(startDay: start, endDay: end, calendar: appModel.settings.calendar) : nil
    }
}
