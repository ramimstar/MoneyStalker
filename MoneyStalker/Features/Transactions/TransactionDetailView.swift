import SwiftData
import SwiftUI
import UIKit

struct TransactionDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [LedgerTransaction]
    var transactionID: UUID
    @State private var showEdit = false
    @State private var showDuplicate = false
    @State private var confirmDelete = false
    @State private var error: String?

    private var transaction: LedgerTransaction? { transactions.first { $0.id == transactionID } }

    var body: some View {
        Group {
            if let transaction {
                List {
                    Section {
                        TransactionRow(transaction: transaction, locale: appModel.settings.formattingLocale)
                        LabeledContent("Date", value: DateFormatting.string(from: transaction.date, style: appModel.settings.dateStyle, locale: appModel.settings.formattingLocale, calendar: appModel.settings.calendar, includeTime: true))
                        LabeledContent("Account", value: transaction.account?.name ?? "—")
                        if transaction.type == .transfer {
                            LabeledContent("To", value: transaction.counterAccount?.name ?? "—")
                            if transaction.currencyCode != transaction.destinationCurrencyCode {
                                LabeledContent("Received", value: MoneyText.string(minor: transaction.destinationAmountMinor, code: transaction.destinationCurrencyCode, locale: appModel.settings.formattingLocale))
                            }
                        }
                        if let category = transaction.category { LabeledContent("Category", value: category.name) }
                        if let subcategory = transaction.subcategory { LabeledContent("Subcategory", value: subcategory.name) }
                        if !transaction.tags.isEmpty { LabeledContent("Tags", value: transaction.tags.joined(separator: ", ")) }
                        if !transaction.notes.isEmpty { Text(transaction.notes) }
                    }
                    if let data = transaction.receiptImage, let image = UIImage(data: data) {
                        Section("Receipt") {
                            Image(uiImage: image).resizable().scaledToFit()
                        }
                    }
                    Section {
                        Button("Edit") { showEdit = true }
                        Button("Duplicate") { showDuplicate = true }
                        Button("Delete", role: .destructive) { confirmDelete = true }
                    }
                }
                .navigationTitle("Transaction")
                .sheet(isPresented: $showEdit) { TransactionEditorView(mode: .edit(transaction)) }
                .sheet(isPresented: $showDuplicate) { TransactionEditorView(mode: .duplicate(transaction)) }
                .moneyStalkerConfirmation(isPresented: $confirmDelete, title: "Delete this transaction?", message: "Balances, budgets, and reports will use the remaining records.", confirmTitle: "Delete") {
                    delete(transaction)
                }
            } else {
                ContentUnavailableView("Transaction removed", systemImage: "trash")
            }
        }
        .alert("Couldn't delete", isPresented: errorShown) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    private func delete(_ transaction: LedgerTransaction) {
        do {
            try TransactionWriter.delete(transaction, context: context)
            Task { await BudgetAlertService.evaluate(context: context, settings: appModel.settings) }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
