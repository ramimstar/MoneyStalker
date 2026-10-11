import SwiftData
import SwiftUI

struct AccountsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var transactions: [LedgerTransaction]
    @State private var showEditor = false
    @State private var editing: Account?

    var body: some View {
        List {
            Section("Active") {
                ForEach(accounts.filter { !$0.isArchived }) { account in
                    NavigationLink(value: AppRoute.account(account.id)) {
                        accountRow(account)
                    }
                    .swipeActions {
                        Button("Edit") { editing = account; showEditor = true }.tint(Color.moneyStalkerPrimary)
                        Button(account.isArchived ? "Unarchive" : "Archive") { toggleArchive(account) }.tint(Color.moneyStalkerWarning)
                    }
                }
            }
            if accounts.contains(where: \.isArchived) {
                Section("Archived") {
                    ForEach(accounts.filter(\.isArchived)) { account in
                        NavigationLink(value: AppRoute.account(account.id)) { accountRow(account) }
                    }
                }
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = nil; showEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add account")
            }
        }
        .sheet(isPresented: $showEditor) { AccountEditorView(account: editing) }
        .moneyStalkerDestinations()
    }

    private func accountRow(_ account: Account) -> some View {
        HStack {
            CategoryIcon(systemName: account.icon, hex: account.colorHex)
            VStack(alignment: .leading) {
                Text(account.name).font(.body.weight(.semibold))
                Text(account.currencyCode).font(.caption).foregroundStyle(Color.moneyStalkerSlate)
            }
            Spacer()
            Text(MoneyText.string(minor: LedgerCalculator.balanceMinor(for: account.snapshot, transactions: transactions.map(\.snapshot)), code: account.currencyCode, locale: appModel.settings.formattingLocale))
                .font(.subheadline.weight(.semibold))
        }
    }

    private func toggleArchive(_ account: Account) {
        account.isArchived.toggle()
        account.updatedAt = .now
        try? context.save()
    }
}

struct AccountDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Query private var accounts: [Account]
    @Query private var transactions: [LedgerTransaction]
    var accountID: UUID
    @State private var showEditor = false

    private var account: Account? { accounts.first { $0.id == accountID } }

    var body: some View {
        Group {
            if let account {
                let breakdown = LedgerCalculator.breakdown(for: account.snapshot, transactions: transactions.map(\.snapshot))
                List {
                    Section {
                        CurrencyAmountView(minor: breakdown.balanceMinor, currencyCode: account.currencyCode, locale: appModel.settings.formattingLocale, emphasis: .large)
                        Text(account.type == .credit && breakdown.balanceMinor < 0 ? "Amount owed on this card." : "Balance from the opening amount and every linked record.")
                            .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                    }
                    Section("How this balance is built") {
                        row("Opening", breakdown.openingMinor, account.currencyCode)
                        row("Income", breakdown.incomeMinor, account.currencyCode, tint: .moneyStalkerIncome)
                        row("Expenses", -breakdown.expenseMinor, account.currencyCode)
                        row("Transfers in", breakdown.transfersInMinor, account.currencyCode)
                        row("Transfers out", -breakdown.transfersOutMinor, account.currencyCode)
                        row("Principal in", breakdown.principalInMinor, account.currencyCode)
                        row("Principal out", -breakdown.principalOutMinor, account.currencyCode)
                    }
                    Section("Transactions") {
                        ForEach(transactions.filter { $0.account?.id == account.id || $0.counterAccount?.id == account.id }) { transaction in
                            NavigationLink(value: AppRoute.transaction(transaction.id)) {
                                TransactionRow(transaction: transaction, locale: appModel.settings.formattingLocale)
                            }
                        }
                    }
                }
                .navigationTitle(account.name)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEditor = true } } }
                .sheet(isPresented: $showEditor) { AccountEditorView(account: account) }
            } else {
                ContentUnavailableView("Account unavailable", systemImage: "wallet.pass")
            }
        }
    }

    private func row(_ title: String, _ minor: Int64, _ code: String, tint: Color = .moneyStalkerSecondary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(MoneyText.string(minor: minor, code: code, locale: appModel.settings.formattingLocale))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }
}

struct AccountEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [LedgerTransaction]
    var account: Account?
    @State private var name = ""
    @State private var type: AccountType = .cash
    @State private var customType = ""
    @State private var currency = "USD"
    @State private var opening = ""
    @State private var icon = "banknote"
    @State private var color = "1877F2"
    @State private var notes = ""
    @State private var creditLimit = ""
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) { ForEach(AccountType.allCases) { Text($0.title).tag($0) } }
                if type == .custom { TextField("Custom type", text: $customType) }
                Picker("Currency", selection: $currency) { ForEach(CurrencyCatalog.common) { Text("\($0.code) · \($0.name)").tag($0.code) } }
                MoneyPadField(text: $opening, placeholder: "Opening balance", locale: appModel.settings.formattingLocale)
                if type == .credit { MoneyPadField(text: $creditLimit, placeholder: "Credit limit", locale: appModel.settings.formattingLocale) }
                TextField("Notes", text: $notes, axis: .vertical)
                iconPicker
                colorPicker
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle(account == nil ? "New account" : "Edit account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear(perform: load)
        }
    }

    private var iconPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))]) {
            ForEach(MoneyStalkerPalette.icons, id: \.self) { symbol in
                Button { icon = symbol } label: {
                    Image(systemName: symbol).frame(width: 36, height: 36)
                        .foregroundStyle(icon == symbol ? Color.moneyStalkerPrimary : Color.moneyStalkerSlate)
                }
                .accessibilityLabel(symbol)
            }
        }
    }

    private var colorPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))]) {
            ForEach(MoneyStalkerPalette.colors, id: \.self) { hex in
                Button { color = hex } label: {
                    Circle().fill(Color(moneyStalkerHex: hex)).frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.primary, lineWidth: color == hex ? 2 : 0))
                }
                .accessibilityLabel("Color \(hex)")
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        currency = appModel.settings.currencyCode
        if let account {
            name = account.name
            type = account.type
            customType = account.customTypeName
            currency = account.currencyCode
            opening = MoneyText.plain(minor: account.openingBalanceMinor, code: account.currencyCode)
            icon = account.icon
            color = account.colorHex
            notes = account.notes
            creditLimit = MoneyText.plain(minor: account.creditLimitMinor, code: account.currencyCode)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "Enter a name."; return }
        guard let openingMinor = MoneyInput.minorUnits(from: opening.isEmpty ? "0" : opening, currencyCode: currency, locale: appModel.settings.formattingLocale) else {
            error = "Enter a valid opening balance."
            return
        }
        let limit = MoneyInput.minorUnits(from: creditLimit.isEmpty ? "0" : creditLimit, currencyCode: currency, locale: appModel.settings.formattingLocale) ?? 0
        if let account {
            let used = transactions.contains { $0.account?.id == account.id || $0.counterAccount?.id == account.id }
            if used && account.currencyCode != currency {
                error = "Currency stays fixed after transactions exist, so old records keep their currency."
                return
            }
            account.name = trimmed
            account.type = type
            account.customTypeName = customType
            account.currencyCode = currency
            account.openingBalanceMinor = openingMinor
            account.icon = icon
            account.colorHex = color
            account.notes = notes
            account.creditLimitMinor = limit
            account.updatedAt = .now
        } else {
            let created = Account(name: trimmed, type: type, customTypeName: customType, openingBalanceMinor: openingMinor, currencyCode: currency, icon: icon, colorHex: color, notes: notes, creditLimitMinor: limit)
            context.insert(created)
        }
        do {
            try context.save()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
