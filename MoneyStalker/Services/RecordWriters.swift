import Foundation
import SwiftData

enum RecordError: LocalizedError {
    case missingAccount
    case missingDebt
    case missingGoal
    case repaymentTooLarge
    case currencyMismatch
    case deleteBlocked(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAccount: "Choose both accounts for a transfer, or neither to record the goal only."
        case .missingDebt: "That debt could not be found."
        case .missingGoal: "That savings goal could not be found."
        case .repaymentTooLarge: "A repayment cannot be larger than the outstanding balance."
        case .currencyMismatch: "Use the same currency as the record, or enter an explicit converted amount where the form allows it."
        case .deleteBlocked(let message): message
        case .saveFailed(let message): message
        }
    }
}

@MainActor
enum TransactionWriter {
    static func create(
        draft: TransactionDraft,
        account: Account,
        counterAccount: Account?,
        category: Category?,
        subcategory: Category?,
        receipt: Data?,
        context: ModelContext,
        existing: [TransactionSnapshot],
        allowDuplicate: Bool
    ) throws -> LedgerTransaction {
        let resolved = try resolvedDraft(draft, account: account, counterAccount: counterAccount, category: category)
        let accounts = try context.fetch(FetchDescriptor<Account>()).map(\.snapshot)
        try TransactionValidator.validate(resolved, accounts: accounts, allowArchived: false)
        if !allowDuplicate && TransactionValidator.isLikelyDuplicate(resolved, existing: existing) {
            throw TransactionDraftError.likelyDuplicate
        }
        let transaction = make(resolved, account: account, counterAccount: counterAccount, category: category, subcategory: subcategory, receipt: receipt)
        context.insert(transaction)
        try context.save()
        return transaction
    }

    static func update(
        _ transaction: LedgerTransaction,
        draft: TransactionDraft,
        account: Account,
        counterAccount: Account?,
        category: Category?,
        subcategory: Category?,
        receipt: Data?,
        context: ModelContext
    ) throws {
        var editing = draft
        editing.editingID = transaction.id
        let resolved = try resolvedDraft(editing, account: account, counterAccount: counterAccount, category: category)
        let accounts = try context.fetch(FetchDescriptor<Account>()).map(\.snapshot)
        try TransactionValidator.validate(resolved, accounts: accounts, allowArchived: true)
        transaction.amountMinor = resolved.amountMinor
        transaction.destinationAmountMinor = resolved.destinationAmountMinor ?? resolved.amountMinor
        transaction.type = resolved.type
        transaction.linkage = resolved.linkage
        transaction.principalDirection = resolved.principalDirection
        transaction.currencyCode = account.currencyCode
        transaction.destinationCurrencyCode = counterAccount?.currencyCode ?? account.currencyCode
        transaction.date = resolved.date
        transaction.notes = resolved.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.tags = normalize(resolved.tags)
        transaction.updatedAt = .now
        transaction.account = account
        transaction.counterAccount = resolved.type == .transfer ? counterAccount : nil
        transaction.category = (resolved.type == .income || resolved.type == .expense) ? category : nil
        transaction.subcategory = transaction.category == nil ? nil : subcategory
        if let receipt {
            transaction.receiptImage = receipt
        }
        try context.save()
    }

    static func duplicate(_ transaction: LedgerTransaction) -> TransactionDraft {
        TransactionDraft(
            amountMinor: transaction.amountMinor,
            destinationAmountMinor: transaction.destinationAmountMinor,
            type: transaction.type,
            linkage: transaction.linkage == .debtPrincipal || transaction.linkage == .debtRepayment || transaction.linkage == .goalFunding ? .none : transaction.linkage,
            principalDirection: transaction.principalDirection,
            accountID: transaction.account?.id,
            counterAccountID: transaction.counterAccount?.id,
            categoryID: transaction.category?.id,
            subcategoryID: transaction.subcategory?.id,
            date: .now,
            notes: transaction.notes,
            tags: transaction.tags,
            sourceCurrencyCode: transaction.currencyCode,
            destinationCurrencyCode: transaction.destinationCurrencyCode
        )
    }

    static func delete(_ transaction: LedgerTransaction, context: ModelContext) throws {
        if transaction.linkage == .debtPrincipal {
            throw RecordError.deleteBlocked("Delete the debt record to remove the original loan movement.")
        }
        for contribution in transaction.contributionLinks {
            context.delete(contribution)
        }
        for repayment in transaction.repaymentLinks {
            context.delete(repayment)
        }
        context.delete(transaction)
        try context.save()
    }

    private static func resolvedDraft(_ draft: TransactionDraft, account: Account, counterAccount: Account?, category: Category?) throws -> TransactionDraft {
        var resolved = draft
        resolved.accountID = account.id
        resolved.sourceCurrencyCode = account.currencyCode
        resolved.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        resolved.tags = normalize(draft.tags)
        if draft.type == .transfer {
            guard let counterAccount else { throw TransactionDraftError.missingCounterAccount }
            resolved.counterAccountID = counterAccount.id
            resolved.destinationCurrencyCode = counterAccount.currencyCode
            if account.currencyCode == counterAccount.currencyCode {
                resolved.destinationAmountMinor = draft.amountMinor
            }
            resolved.categoryID = nil
            resolved.subcategoryID = nil
        } else if draft.type == .principal {
            resolved.categoryID = nil
            resolved.subcategoryID = nil
            resolved.destinationAmountMinor = draft.amountMinor
            resolved.destinationCurrencyCode = account.currencyCode
        } else {
            resolved.categoryID = category?.id
            resolved.destinationAmountMinor = draft.amountMinor
            resolved.destinationCurrencyCode = account.currencyCode
        }
        return resolved
    }

    private static func make(
        _ draft: TransactionDraft,
        account: Account,
        counterAccount: Account?,
        category: Category?,
        subcategory: Category?,
        receipt: Data?
    ) -> LedgerTransaction {
        let transaction = LedgerTransaction(
            amountMinor: draft.amountMinor,
            destinationAmountMinor: draft.destinationAmountMinor ?? draft.amountMinor,
            type: draft.type,
            linkage: draft.linkage,
            principalDirection: draft.principalDirection,
            currencyCode: account.currencyCode,
            destinationCurrencyCode: counterAccount?.currencyCode ?? account.currencyCode,
            date: draft.date,
            notes: draft.notes,
            tags: draft.tags,
            receiptImage: receipt,
            linkedDebtID: nil,
            linkedGoalID: nil
        )
        transaction.account = account
        transaction.counterAccount = draft.type == .transfer ? counterAccount : nil
        transaction.category = (draft.type == .income || draft.type == .expense) ? category : nil
        transaction.subcategory = transaction.category == nil ? nil : subcategory
        return transaction
    }

    private static func normalize(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}

@MainActor
enum DebtWriter {
    static func create(
        person: String,
        direction: DebtDirection,
        amountMinor: Int64,
        currencyCode: String,
        account: Account?,
        dueDate: Date?,
        interestRateText: String,
        notes: String,
        reminder: Bool,
        date: Date,
        context: ModelContext
    ) throws -> Debt {
        let trimmed = person.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RecordError.saveFailed("Enter the person or organization.") }
        guard amountMinor > 0 else { throw TransactionDraftError.invalidAmount }
        if let account, account.currencyCode.isEmpty { throw RecordError.currencyMismatch }
        let debt = Debt(
            person: trimmed,
            direction: direction,
            originalMinor: amountMinor,
            currencyCode: account?.currencyCode ?? currencyCode,
            dueDate: dueDate,
            interestRateText: interestRateText.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            reminderEnabled: reminder
        )
        context.insert(debt)
        debt.account = account
        if let account {
            let principalDirection: PrincipalDirection = direction == .borrowed ? .inbound : .outbound
            let transaction = LedgerTransaction(
                amountMinor: amountMinor,
                destinationAmountMinor: amountMinor,
                type: .principal,
                linkage: .debtPrincipal,
                principalDirection: principalDirection,
                currencyCode: account.currencyCode,
                destinationCurrencyCode: account.currencyCode,
                date: date,
                notes: notes,
                linkedDebtID: debt.id
            )
            context.insert(transaction)
            transaction.account = account
            debt.currencyCode = account.currencyCode
        }
        try context.save()
        return debt
    }

    @discardableResult
    static func repay(debt: Debt, amountMinor: Int64, account: Account, date: Date, notes: String, context: ModelContext, occurrenceKey: String? = nil) throws -> LedgerTransaction {
        let summary = DebtMath.summary(debt: debt.snapshot, repayments: debt.repayments.map(\.snapshot))
        guard amountMinor > 0 else { throw TransactionDraftError.invalidAmount }
        guard amountMinor <= summary.outstandingMinor else { throw RecordError.repaymentTooLarge }
        guard account.currencyCode == debt.currencyCode else { throw RecordError.currencyMismatch }
        let repayment = DebtRepayment(amountMinor: amountMinor, date: date, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(repayment)
        repayment.debt = debt
        let principalDirection: PrincipalDirection = debt.direction == .borrowed ? .outbound : .inbound
        let transaction = LedgerTransaction(
            amountMinor: amountMinor,
            destinationAmountMinor: amountMinor,
            type: .principal,
            linkage: .debtRepayment,
            principalDirection: principalDirection,
            currencyCode: account.currencyCode,
            destinationCurrencyCode: account.currencyCode,
            date: date,
            notes: notes,
            linkedDebtID: debt.id,
            linkedRepaymentID: repayment.id
        )
        transaction.occurrenceKey = occurrenceKey
        context.insert(transaction)
        transaction.account = account
        repayment.transaction = transaction
        try context.save()
        return transaction
    }

    static func recordInterest(debt: Debt, amountMinor: Int64, account: Account, category: Category, date: Date, notes: String, context: ModelContext) throws {
        guard amountMinor > 0 else { throw TransactionDraftError.invalidAmount }
        guard account.currencyCode == debt.currencyCode else { throw RecordError.currencyMismatch }
        let type: TransactionType = debt.direction == .borrowed ? .expense : .income
        let transaction = LedgerTransaction(
            amountMinor: amountMinor,
            destinationAmountMinor: amountMinor,
            type: type,
            linkage: .debtInterest,
            currencyCode: account.currencyCode,
            destinationCurrencyCode: account.currencyCode,
            date: date,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            linkedDebtID: debt.id
        )
        context.insert(transaction)
        transaction.account = account
        transaction.category = category
        try context.save()
    }

    static func delete(debt: Debt, context: ModelContext) throws {
        let debtID = debt.id
        let transactions = try context.fetch(FetchDescriptor<LedgerTransaction>())
        for transaction in transactions where transaction.linkedDebtID == debtID {
            context.delete(transaction)
        }
        context.delete(debt)
        try context.save()
    }
}

@MainActor
enum GoalWriter {
    static func addContribution(
        goal: SavingsGoal,
        amountMinor: Int64,
        date: Date,
        notes: String,
        from: Account?,
        to: Account?,
        context: ModelContext
    ) throws {
        guard amountMinor > 0 else { throw TransactionDraftError.invalidAmount }
        if (from == nil) != (to == nil) { throw RecordError.missingAccount }
        if let from, let to {
            guard from.id != to.id else { throw TransactionDraftError.sameAccountTransfer }
            guard from.currencyCode == to.currencyCode, from.currencyCode == goal.currencyCode else {
                throw RecordError.currencyMismatch
            }
        }
        let contribution = SavingsContribution(amountMinor: amountMinor, date: date, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(contribution)
        contribution.goal = goal
        if let from, let to {
            let transaction = LedgerTransaction(
                amountMinor: amountMinor,
                destinationAmountMinor: amountMinor,
                type: .transfer,
                linkage: .goalFunding,
                currencyCode: from.currencyCode,
                destinationCurrencyCode: to.currencyCode,
                date: date,
                notes: notes,
                linkedGoalID: goal.id,
                linkedContributionID: contribution.id
            )
            context.insert(transaction)
            transaction.account = from
            transaction.counterAccount = to
            contribution.transaction = transaction
        }
        try context.save()
    }

    static func deleteContribution(_ contribution: SavingsContribution, context: ModelContext) throws {
        if let transaction = contribution.transaction {
            context.delete(transaction)
        }
        context.delete(contribution)
        try context.save()
    }

    static func deleteGoal(_ goal: SavingsGoal, context: ModelContext) throws {
        context.delete(goal)
        try context.save()
    }
}

@MainActor
enum DataWipe {
    static func deleteRecords(context: ModelContext) throws {
        for link in try context.fetch(FetchDescriptor<RamadanLink>()) { context.delete(link) }
        for plan in try context.fetch(FetchDescriptor<RamadanPlan>()) { context.delete(plan) }
        for record in try context.fetch(FetchDescriptor<CharityRecord>()) { context.delete(record) }
        for goal in try context.fetch(FetchDescriptor<CharityGoal>()) { context.delete(goal) }
        for mark in try context.fetch(FetchDescriptor<LibraryBookmark>()) { context.delete(mark) }
        for visit in try context.fetch(FetchDescriptor<LibraryVisit>()) { context.delete(visit) }
        for calculation in try context.fetch(FetchDescriptor<ZakatCalculationRecord>()) { context.delete(calculation) }
        for transaction in try context.fetch(FetchDescriptor<LedgerTransaction>()) { context.delete(transaction) }
        for repayment in try context.fetch(FetchDescriptor<DebtRepayment>()) { context.delete(repayment) }
        for contribution in try context.fetch(FetchDescriptor<SavingsContribution>()) { context.delete(contribution) }
        for debt in try context.fetch(FetchDescriptor<Debt>()) { context.delete(debt) }
        for goal in try context.fetch(FetchDescriptor<SavingsGoal>()) { context.delete(goal) }
        for rule in try context.fetch(FetchDescriptor<RecurringRule>()) { context.delete(rule) }
        for budget in try context.fetch(FetchDescriptor<Budget>()) { context.delete(budget) }
        for category in try context.fetch(FetchDescriptor<Category>()) { context.delete(category) }
        for account in try context.fetch(FetchDescriptor<Account>()) { context.delete(account) }
        try context.save()
    }

    static func eraseEverything(context: ModelContext, settings: SettingsStore) throws {
        try deleteRecords(context: context)
        settings.resetFinancialPreferences()
        try SeedService.seedIfNeeded(context: context)
    }
}
