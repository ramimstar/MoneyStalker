import PhotosUI
import SwiftData
import SwiftUI
import UIKit

enum TransactionEditorMode {
    case create
    case edit(LedgerTransaction)
    case duplicate(LedgerTransaction)
}

struct TransactionEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var transactions: [LedgerTransaction]

    var mode: TransactionEditorMode
    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var destinationText = ""
    @State private var accountID: UUID?
    @State private var counterID: UUID?
    @State private var categoryID: UUID?
    @State private var subcategoryID: UUID?
    @State private var date = Date()
    @State private var notes = ""
    @State private var tags = ""
    @State private var photo: PhotosPickerItem?
    @State private var receipt: Data?
    @State private var existingReceipt: Data?
    @State private var error: String?
    @State private var showDuplicate = false
    @State private var loaded = false
    @State private var editing: LedgerTransaction?
    @State private var showDetails = false
    @State private var keyboardVisible = false
    @State private var showAddCategory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if activeAccounts.isEmpty {
                        EmptyStateView(systemImage: "wallet.pass", title: "Add an account first", message: "Transactions need an account so the balance stays consistent.", actionTitle: nil, action: nil)
                    } else {
                        form
                    }
                }
                .padding(16)
            }
            .moneyStalkerScreen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 12) {
                if !activeAccounts.isEmpty, !keyboardVisible {
                    PrimaryButton(title: "Save", enabled: canSave) { save(allowDuplicate: false) }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        .background(Color.moneyStalkerCard)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    Spacer()
                    Button("Save") { save(allowDuplicate: false) }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
            .sheet(isPresented: $showAddCategory) {
                CategoryEditorView(kind: kind) { created in
                    if let parentID = created.parent?.id {
                        categoryID = parentID
                        subcategoryID = created.id
                    } else {
                        categoryID = created.id
                        subcategoryID = nil
                    }
                }
            }
            .onAppear(perform: load)
            .onChange(of: photo) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        receipt = ImagePrep.jpegData(from: data) ?? data
                    }
                }
            }
            .alert("Possible duplicate", isPresented: $showDuplicate) {
                Button("Save anyway") { save(allowDuplicate: true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A similar transaction was saved in the last couple of minutes.")
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            if editing?.type == .principal {
                Text("Loan principal").font(.headline)
                Text("This movement changes the balance. It is not income or an expense.")
                    .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
            } else {
                typeChips
            }
            AmountTextField(text: $amountText, currencyCode: selectedAccount?.currencyCode ?? appModel.settings.currencyCode, locale: appModel.settings.formattingLocale)
                .moneyStalkerCard(graph: .line)
            if type == .transfer, let source = selectedAccount, let destination = selectedCounter, source.currencyCode != destination.currencyCode {
                Text("Amount received in \(destination.currencyCode)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSlate)
                AmountTextField(text: $destinationText, currencyCode: destination.currencyCode, locale: appModel.settings.formattingLocale)
                    .moneyStalkerCard(graph: .area)
            }
            VStack(spacing: 4) {
                accountPicker
                if type == .transfer { counterPicker }
                DatePicker("Date", selection: $date)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background { MoneyStalkerMesh(style: .card, graph: .ring) }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
            if type == .transfer {
                Text("Transfers move money between accounts. They stay out of income and expenses.")
                    .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
            } else if type != .principal {
                categoryGrid
            }
            details
            if let error { Text(error).font(.footnote).foregroundStyle(Color.moneyStalkerExpense) }
        }
    }

    private var typeChips: some View {
        HStack(spacing: 8) {
            ForEach(typeChoices) { item in
                Button {
                    type = item
                } label: {
                    Label(item.title, systemImage: chipSymbol(item))
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(type == item ? Color.moneyStalkerOnHero : Color.moneyStalkerSecondary)
                        .background(type == item ? chipColor(item) : Color.moneyStalkerCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(type == item ? Color.clear : Color.moneyStalkerBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(type == item ? .isSelected : [])
            }
        }
    }

    private var details: some View {
        DisclosureGroup(isExpanded: $showDetails) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
                TextField("Tags, separated by commas", text: $tags)
                PhotosPicker(selection: $photo, matching: .images) {
                    Label(receipt == nil && existingReceipt == nil ? "Add receipt" : "Replace receipt", systemImage: "photo")
                }
                .accessibilityLabel("Add receipt photo")
                if let data = receipt ?? existingReceipt, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Notes, tags, and receipt")
                .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background { MoneyStalkerMesh(style: .card, graph: .dots) }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
    }

    private var typeChoices: [TransactionType] {
        switch mode {
        case .edit(let transaction), .duplicate(let transaction):
            return transaction.type == .transfer ? [.expense, .income, .transfer] : [.expense, .income]
        case .create:
            return [.expense, .income]
        }
    }

    private func chipSymbol(_ item: TransactionType) -> String {
        switch item {
        case .expense: "arrow.up.right"
        case .income: "arrow.down.left"
        case .transfer: "arrow.left.arrow.right"
        case .principal: "person.2"
        }
    }

    private func chipColor(_ item: TransactionType) -> Color {
        switch item {
        case .expense: Color.moneyStalkerExpense
        case .income: Color.moneyStalkerIncome
        default: Color.moneyStalkerPrimary
        }
    }

    private var accountPicker: some View {
        Picker(type == .transfer ? "From" : "Account", selection: $accountID) {
            Text("Choose").tag(Optional<UUID>.none)
            ForEach(activeAccounts) { account in
                Text("\(account.name) · \(account.currencyCode)").tag(Optional(account.id))
            }
        }
    }

    private var counterPicker: some View {
        Picker("To", selection: $counterID) {
            Text("Choose").tag(Optional<UUID>.none)
            ForEach(activeAccounts) { account in
                Text("\(account.name) · \(account.currencyCode)").tag(Optional(account.id))
            }
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                ForEach(topCategories) { category in
                    Button { categoryID = category.id; subcategoryID = nil } label: {
                        VStack(spacing: 6) {
                            CategoryIcon(systemName: category.icon, hex: category.colorHex)
                            Text(category.name).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(categoryID == category.id ? Color.moneyStalkerPrimary.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(categoryID == category.id ? Color.moneyStalkerPrimary : Color.moneyStalkerBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.name)
                    .accessibilityAddTraits(categoryID == category.id ? .isSelected : [])
                }
                Button {
                    showAddCategory = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.moneyStalkerPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.moneyStalkerPrimary.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text("Add category")
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.moneyStalkerSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add category")
            }
            if !children.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(children) { child in
                            Button(child.name) { subcategoryID = child.id }
                                .buttonStyle(.bordered)
                                .tint(subcategoryID == child.id ? Color.moneyStalkerPrimary : Color.moneyStalkerSlate)
                        }
                    }
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .create: "Add transaction"
        case .edit: "Edit transaction"
        case .duplicate: "Duplicate"
        }
    }

    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived || $0.id == accountID || $0.id == counterID } }
    private var selectedAccount: Account? { accounts.first { $0.id == accountID } }
    private var selectedCounter: Account? { accounts.first { $0.id == counterID } }
    private var kind: CategoryKind { type == .income ? .income : .expense }
    private var topCategories: [Category] { categories.filter { $0.kind == kind && $0.parent == nil && (!$0.isArchived || $0.id == categoryID) } }
    private var children: [Category] { categories.filter { $0.parent?.id == categoryID && (!$0.isArchived || $0.id == subcategoryID) } }
    private var canSave: Bool { !activeAccounts.isEmpty && !(MoneyInput.minorUnits(from: amountText, currencyCode: selectedAccount?.currencyCode ?? appModel.settings.currencyCode, locale: appModel.settings.formattingLocale) == nil) }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .create:
            type = .expense
            accountID = UUID(uuidString: appModel.settings.lastAccountID) ?? activeAccounts.first?.id
            categoryID = UUID(uuidString: appModel.settings.lastExpenseCategoryID)
        case .edit(let transaction), .duplicate(let transaction):
            if case .edit = mode { editing = transaction }
            type = transaction.type
            amountText = MoneyText.plain(minor: transaction.amountMinor, code: transaction.currencyCode).replacingOccurrences(of: ".", with: appModel.settings.formattingLocale.decimalSeparator ?? ".")
            destinationText = MoneyText.plain(minor: transaction.destinationAmountMinor, code: transaction.destinationCurrencyCode)
            accountID = transaction.account?.id
            counterID = transaction.counterAccount?.id
            categoryID = transaction.category?.id
            subcategoryID = transaction.subcategory?.id
            date = transaction.date
            notes = transaction.notes
            tags = transaction.tags.joined(separator: ", ")
            existingReceipt = transaction.receiptImage
        }
    }

    private func save(allowDuplicate: Bool) {
        guard let account = selectedAccount else { error = "Choose an account."; return }
        let minor = MoneyInput.minorUnits(from: amountText, currencyCode: account.currencyCode, locale: appModel.settings.formattingLocale)
        guard let minor else { error = "Enter an amount greater than zero."; return }
        let destinationMinor = MoneyInput.minorUnits(from: destinationText, currencyCode: selectedCounter?.currencyCode ?? account.currencyCode, locale: appModel.settings.formattingLocale)
        let category = categories.first { $0.id == categoryID }
        let subcategory = categories.first { $0.id == subcategoryID }
        var draft = TransactionDraft(
            amountMinor: minor,
            destinationAmountMinor: destinationMinor,
            type: editing?.type == .principal ? .principal : type,
            linkage: editing?.linkage ?? .none,
            principalDirection: editing?.principalDirection ?? .outbound,
            accountID: account.id,
            counterAccountID: counterID,
            categoryID: category?.id,
            subcategoryID: subcategory?.id,
            date: date,
            notes: notes,
            tags: tags.split(separator: ",").map { String($0) },
            sourceCurrencyCode: account.currencyCode,
            destinationCurrencyCode: selectedCounter?.currencyCode,
            editingID: editing?.id
        )
        if editing?.type == .principal { draft.type = .principal }
        do {
            if let editing {
                try TransactionWriter.update(editing, draft: draft, account: account, counterAccount: selectedCounter, category: category, subcategory: subcategory, receipt: receipt, context: context)
            } else {
                _ = try TransactionWriter.create(draft: draft, account: account, counterAccount: selectedCounter, category: category, subcategory: subcategory, receipt: receipt ?? existingReceipt, context: context, existing: transactions.map(\.snapshot), allowDuplicate: allowDuplicate)
            }
            appModel.settings.lastAccountID = account.id.uuidString
            if draft.type == .expense, let category { appModel.settings.lastExpenseCategoryID = category.id.uuidString }
            if draft.type == .income, let category { appModel.settings.lastIncomeCategoryID = category.id.uuidString }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { await BudgetAlertService.evaluate(context: context, settings: appModel.settings) }
            dismiss()
        } catch TransactionDraftError.likelyDuplicate {
            showDuplicate = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

enum ImagePrep {
    static func jpegData(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.72) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let ratio = longest > 0 ? min(1, maxDimension / longest) : 1
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: size)
        let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return scaled.jpegData(compressionQuality: quality)
    }
}
