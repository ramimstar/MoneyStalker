import Foundation
import SwiftData

@MainActor
enum BackupService {
    static func makeFile(context: ModelContext, settings: SettingsStore) throws -> BackupFile {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let transactions = try context.fetch(FetchDescriptor<LedgerTransaction>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let rules = try context.fetch(FetchDescriptor<RecurringRule>())
        let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
        let contributions = try context.fetch(FetchDescriptor<SavingsContribution>())
        let debts = try context.fetch(FetchDescriptor<Debt>())
        let repayments = try context.fetch(FetchDescriptor<DebtRepayment>())
        let zakatCalculations = try context.fetch(FetchDescriptor<ZakatCalculationRecord>())
        let charityRecords = try context.fetch(FetchDescriptor<CharityRecord>())
        let charityGoals = try context.fetch(FetchDescriptor<CharityGoal>())
        let ramadanPlans = try context.fetch(FetchDescriptor<RamadanPlan>())
        let ramadanLinks = try context.fetch(FetchDescriptor<RamadanLink>())
        let libraryBookmarks = try context.fetch(FetchDescriptor<LibraryBookmark>())
        let libraryVisits = try context.fetch(FetchDescriptor<LibraryVisit>())
        return BackupFile(
            formatVersion: BackupFile.currentVersion,
            exportedAt: .now,
            accounts: accounts.map(accountDTO),
            categories: categories.map(categoryDTO),
            transactions: transactions.map(transactionDTO),
            budgets: budgets.map(budgetDTO),
            recurringRules: rules.map(ruleDTO),
            goals: goals.map(goalDTO),
            contributions: contributions.map(contributionDTO),
            debts: debts.map(debtDTO),
            repayments: repayments.map(repaymentDTO),
            zakatCalculations: zakatCalculations.map(zakatDTO),
            charityRecords: charityRecords.map(charityDTO),
            charityGoals: charityGoals.map(charityGoalDTO),
            ramadanPlans: ramadanPlans.map(ramadanDTO),
            ramadanLinks: ramadanLinks.map(ramadanLinkDTO),
            libraryBookmarks: libraryBookmarks.map { LibraryMarkDTO(articleID: $0.articleID, date: $0.savedAt) },
            libraryVisits: libraryVisits.map { LibraryMarkDTO(articleID: $0.articleID, date: $0.viewedAt) },
            settings: settings.backupDTO()
        )
    }

    static func exportData(context: ModelContext, settings: SettingsStore) throws -> Data {
        try BackupCodec.encode(try makeFile(context: context, settings: settings))
    }

    static func restore(data: Data, context: ModelContext, settings: SettingsStore, directory: URL) throws {
        let file = try BackupCodec.decode(data)
        try RestoreGuard.begin(data: data, directory: directory)
        try replace(file, context: context, settings: settings)
        RestoreGuard.finish(directory: directory)
    }

    static func recoverIfNeeded(context: ModelContext, settings: SettingsStore, directory: URL) throws {
        guard RestoreGuard.needsRecovery(directory: directory), let data = RestoreGuard.recoveryData(directory: directory) else { return }
        let file = try BackupCodec.decode(data)
        try replace(file, context: context, settings: settings)
        RestoreGuard.finish(directory: directory)
    }

    static func supportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("MoneyStalker", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func replace(_ file: BackupFile, context: ModelContext, settings: SettingsStore) throws {
        try DataWipe.deleteRecords(context: context)
        var accounts: [UUID: Account] = [:]
        for dto in file.accounts {
            let account = Account(
                id: dto.id,
                name: dto.name,
                type: AccountType(rawValue: dto.type) ?? .cash,
                customTypeName: dto.customTypeName,
                openingBalanceMinor: dto.openingBalanceMinor,
                currencyCode: dto.currencyCode,
                icon: dto.icon,
                colorHex: dto.colorHex,
                notes: dto.notes,
                isArchived: dto.isArchived,
                sortOrder: dto.sortOrder,
                creditLimitMinor: dto.creditLimitMinor,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            context.insert(account)
            accounts[dto.id] = account
        }
        var categories: [UUID: Category] = [:]
        for dto in file.categories {
            let category = Category(
                id: dto.id,
                name: dto.name,
                kind: CategoryKind(rawValue: dto.kind) ?? .expense,
                icon: dto.icon,
                colorHex: dto.colorHex,
                isArchived: dto.isArchived,
                isSystem: dto.isSystem,
                sortOrder: dto.sortOrder
            )
            context.insert(category)
            categories[dto.id] = category
        }
        for dto in file.categories {
            categories[dto.id]?.parent = dto.parentID.flatMap { categories[$0] }
        }
        var transactions: [UUID: LedgerTransaction] = [:]
        for dto in file.transactions {
            let transaction = LedgerTransaction(
                id: dto.id,
                amountMinor: dto.amountMinor,
                destinationAmountMinor: dto.destinationAmountMinor,
                type: TransactionType(rawValue: dto.type) ?? .expense,
                linkage: TransactionLinkage(rawValue: dto.linkage) ?? .none,
                principalDirection: PrincipalDirection(rawValue: dto.principalDirection) ?? .outbound,
                currencyCode: dto.currencyCode,
                destinationCurrencyCode: dto.destinationCurrencyCode,
                date: dto.date,
                notes: dto.notes,
                tags: dto.tags,
                occurrenceKey: dto.occurrenceKey,
                receiptImage: dto.receiptBase64.flatMap { Data(base64Encoded: $0) },
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                linkedDebtID: dto.linkedDebtID,
                linkedGoalID: dto.linkedGoalID,
                linkedRepaymentID: dto.linkedRepaymentID,
                linkedContributionID: dto.linkedContributionID
            )
            context.insert(transaction)
            transaction.account = accounts[dto.accountID]
            transaction.counterAccount = dto.counterAccountID.flatMap { accounts[$0] }
            transaction.category = dto.categoryID.flatMap { categories[$0] }
            transaction.subcategory = dto.subcategoryID.flatMap { categories[$0] }
            transactions[dto.id] = transaction
        }
        for dto in file.budgets {
            let budget = Budget(
                id: dto.id,
                name: dto.name,
                kind: BudgetPeriodKind(rawValue: dto.period) ?? .monthly,
                limitMinor: dto.limitMinor,
                currencyCode: dto.currencyCode,
                startDate: dto.startDate,
                endDate: dto.endDate,
                warningThreshold: dto.warningThreshold,
                rollover: dto.rollover,
                isArchived: dto.isArchived,
                createdAt: dto.createdAt,
                category: dto.categoryID.flatMap { categories[$0] }
            )
            context.insert(budget)
        }
        for dto in file.recurringRules {
            let rule = RecurringRule(
                id: dto.id,
                name: dto.name,
                amountMinor: dto.amountMinor,
                destinationAmountMinor: dto.destinationAmountMinor,
                type: TransactionType(rawValue: dto.type) ?? .expense,
                linkage: TransactionLinkage(rawValue: dto.linkage) ?? .none,
                principalDirection: PrincipalDirection(rawValue: dto.principalDirection) ?? .outbound,
                currencyCode: dto.currencyCode,
                destinationCurrencyCode: dto.destinationCurrencyCode,
                frequency: RecurrenceFrequency(rawValue: dto.frequency) ?? .monthly,
                interval: dto.interval,
                startDate: dto.startDate,
                endDate: dto.endDate,
                nextOccurrence: dto.nextOccurrence,
                notes: dto.notes,
                tags: dto.tags,
                reminderEnabled: dto.reminderEnabled,
                reminderLeadMinutes: dto.reminderLeadMinutes,
                isPaused: dto.isPaused,
                processedOccurrenceKeys: dto.processedOccurrenceKeys,
                linkedDebtID: dto.linkedDebtID,
                linkedGoalID: dto.linkedGoalID,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            context.insert(rule)
            rule.account = dto.accountID.flatMap { accounts[$0] }
            rule.counterAccount = dto.counterAccountID.flatMap { accounts[$0] }
            rule.category = dto.categoryID.flatMap { categories[$0] }
        }
        var goals: [UUID: SavingsGoal] = [:]
        for dto in file.goals {
            let goal = SavingsGoal(
                id: dto.id,
                name: dto.name,
                targetMinor: dto.targetMinor,
                currencyCode: dto.currencyCode,
                targetDate: dto.targetDate,
                icon: dto.icon,
                colorHex: dto.colorHex,
                notes: dto.notes,
                createdAt: dto.createdAt
            )
            context.insert(goal)
            goal.linkedAccount = dto.linkedAccountID.flatMap { accounts[$0] }
            goals[dto.id] = goal
        }
        for dto in file.contributions {
            let contribution = SavingsContribution(id: dto.id, amountMinor: dto.amountMinor, date: dto.date, notes: dto.notes, createdAt: dto.createdAt)
            context.insert(contribution)
            contribution.goal = goals[dto.goalID]
            contribution.transaction = dto.transactionID.flatMap { transactions[$0] }
        }
        var debts: [UUID: Debt] = [:]
        for dto in file.debts {
            let debt = Debt(
                id: dto.id,
                person: dto.person,
                direction: DebtDirection(rawValue: dto.direction) ?? .borrowed,
                originalMinor: dto.originalMinor,
                currencyCode: dto.currencyCode,
                dueDate: dto.dueDate,
                interestRateText: dto.interestRateText,
                notes: dto.notes,
                isWrittenOff: dto.isWrittenOff,
                reminderEnabled: dto.reminderEnabled,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            context.insert(debt)
            debt.account = dto.accountID.flatMap { accounts[$0] }
            debts[dto.id] = debt
        }
        for dto in file.repayments {
            let repayment = DebtRepayment(id: dto.id, amountMinor: dto.amountMinor, date: dto.date, notes: dto.notes, createdAt: dto.createdAt)
            context.insert(repayment)
            repayment.debt = debts[dto.debtID]
            repayment.transaction = dto.transactionID.flatMap { transactions[$0] }
        }
        for dto in file.zakatCalculations {
            context.insert(ZakatCalculationRecord(id: dto.id, createdAt: dto.createdAt, currencyCode: dto.currencyCode, methodRaw: dto.methodRaw, hawlConfirmed: dto.hawlConfirmed, hawlDate: dto.hawlDate, cashHomeMinor: dto.cashHomeMinor, bankMinor: dto.bankMinor, investmentsMinor: dto.investmentsMinor, moneyLentMinor: dto.moneyLentMinor, receivablesMinor: dto.receivablesMinor, businessCashMinor: dto.businessCashMinor, inventoryMinor: dto.inventoryMinor, otherAssetsMinor: dto.otherAssetsMinor, includeRetirement: dto.includeRetirement, retirementMinor: dto.retirementMinor, shortTermLiabilitiesMinor: dto.shortTermLiabilitiesMinor, paidInAdvanceMinor: dto.paidInAdvanceMinor, goldGrams: dto.goldGrams, goldKarat: dto.goldKarat, goldPricePerGramMinor: dto.goldPricePerGramMinor, goldPriceSource: dto.goldPriceSource, goldPriceDate: dto.goldPriceDate, silverGrams: dto.silverGrams, silverFineness: dto.silverFineness, silverPricePerGramMinor: dto.silverPricePerGramMinor, silverPriceSource: dto.silverPriceSource, silverPriceDate: dto.silverPriceDate, eligibleAssetsMinor: dto.eligibleAssetsMinor, deductionsMinor: dto.deductionsMinor, netWealthMinor: dto.netWealthMinor, nisabMinor: dto.nisabMinor, nisabKnown: dto.nisabKnown, zakatDueMinor: dto.zakatDueMinor, remainingMinor: dto.remainingMinor, statusRaw: dto.statusRaw, notes: dto.notes, engineVersion: dto.engineVersion))
        }
        for dto in file.charityRecords {
            context.insert(CharityRecord(id: dto.id, kindRaw: dto.kindRaw, amountMinor: dto.amountMinor, currencyCode: dto.currencyCode, date: dto.date, recipient: dto.recipient, notes: dto.notes, receiptImage: dto.receiptBase64.flatMap { Data(base64Encoded: $0) }, transactionID: dto.transactionID, calculationID: dto.calculationID, createdAt: dto.createdAt))
        }
        for dto in file.charityGoals {
            context.insert(CharityGoal(id: dto.id, name: dto.name, cadenceRaw: dto.cadenceRaw, donationKindRaw: dto.donationKindRaw, targetMinor: dto.targetMinor, currencyCode: dto.currencyCode, startDate: dto.startDate, endDate: dto.endDate))
        }
        for dto in file.ramadanPlans {
            let plan = RamadanPlan(id: dto.id, hijriYear: dto.hijriYear, startDate: dto.startDate, endDate: dto.endDate, currencyCode: dto.currencyCode, savingsTargetMinor: dto.savingsTargetMinor, lines: [])
            plan.linesJSON = dto.linesJSON
            context.insert(plan)
        }
        for dto in file.ramadanLinks {
            context.insert(RamadanLink(id: dto.id, planID: dto.planID, lineID: dto.lineID, transactionID: dto.transactionID))
        }
        for dto in file.libraryBookmarks {
            context.insert(LibraryBookmark(articleID: dto.articleID, savedAt: dto.date))
        }
        for dto in file.libraryVisits {
            context.insert(LibraryVisit(articleID: dto.articleID, viewedAt: dto.date))
        }
        settings.applyBackup(file.settings)
        try context.save()
    }

    private static func accountDTO(_ account: Account) -> AccountDTO {
        AccountDTO(id: account.id, name: account.name, type: account.typeRaw, customTypeName: account.customTypeName, openingBalanceMinor: account.openingBalanceMinor, currencyCode: account.currencyCode, icon: account.icon, colorHex: account.colorHex, notes: account.notes, isArchived: account.isArchived, sortOrder: account.sortOrder, creditLimitMinor: account.creditLimitMinor, createdAt: account.createdAt, updatedAt: account.updatedAt)
    }

    private static func categoryDTO(_ category: Category) -> CategoryDTO {
        CategoryDTO(id: category.id, name: category.name, kind: category.kindRaw, icon: category.icon, colorHex: category.colorHex, isArchived: category.isArchived, isSystem: category.isSystem, sortOrder: category.sortOrder, parentID: category.parent?.id)
    }

    private static func transactionDTO(_ transaction: LedgerTransaction) -> TransactionDTO {
        TransactionDTO(
            id: transaction.id,
            amountMinor: transaction.amountMinor,
            destinationAmountMinor: transaction.destinationAmountMinor,
            type: transaction.typeRaw,
            linkage: transaction.linkageRaw,
            principalDirection: transaction.principalDirectionRaw,
            currencyCode: transaction.currencyCode,
            destinationCurrencyCode: transaction.destinationCurrencyCode,
            date: transaction.date,
            notes: transaction.notes,
            tags: transaction.tags,
            occurrenceKey: transaction.occurrenceKey,
            receiptBase64: transaction.receiptImage?.base64EncodedString(),
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt,
            linkedDebtID: transaction.linkedDebtID,
            linkedGoalID: transaction.linkedGoalID,
            linkedRepaymentID: transaction.linkedRepaymentID,
            linkedContributionID: transaction.linkedContributionID,
            accountID: transaction.account?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            counterAccountID: transaction.counterAccount?.id,
            categoryID: transaction.category?.id,
            subcategoryID: transaction.subcategory?.id
        )
    }

    private static func budgetDTO(_ budget: Budget) -> BudgetDTO {
        BudgetDTO(id: budget.id, name: budget.name, period: budget.periodRaw, limitMinor: budget.limitMinor, currencyCode: budget.currencyCode, startDate: budget.startDate, endDate: budget.endDate, warningThreshold: budget.warningThreshold, rollover: budget.rollover, isArchived: budget.isArchived, createdAt: budget.createdAt, categoryID: budget.category?.id)
    }

    private static func ruleDTO(_ rule: RecurringRule) -> RecurringRuleDTO {
        RecurringRuleDTO(id: rule.id, name: rule.name, amountMinor: rule.amountMinor, destinationAmountMinor: rule.destinationAmountMinor, type: rule.typeRaw, linkage: rule.linkageRaw, principalDirection: rule.principalDirectionRaw, currencyCode: rule.currencyCode, destinationCurrencyCode: rule.destinationCurrencyCode, frequency: rule.frequencyRaw, interval: rule.interval, startDate: rule.startDate, endDate: rule.endDate, nextOccurrence: rule.nextOccurrence, notes: rule.notes, tags: rule.tags, reminderEnabled: rule.reminderEnabled, reminderLeadMinutes: rule.reminderLeadMinutes, isPaused: rule.isPaused, processedOccurrenceKeys: rule.processedOccurrenceKeys, linkedDebtID: rule.linkedDebtID, linkedGoalID: rule.linkedGoalID, createdAt: rule.createdAt, updatedAt: rule.updatedAt, accountID: rule.account?.id, counterAccountID: rule.counterAccount?.id, categoryID: rule.category?.id)
    }

    private static func goalDTO(_ goal: SavingsGoal) -> GoalDTO {
        GoalDTO(id: goal.id, name: goal.name, targetMinor: goal.targetMinor, currencyCode: goal.currencyCode, targetDate: goal.targetDate, icon: goal.icon, colorHex: goal.colorHex, notes: goal.notes, createdAt: goal.createdAt, linkedAccountID: goal.linkedAccount?.id)
    }

    private static func contributionDTO(_ contribution: SavingsContribution) -> ContributionDTO {
        ContributionDTO(id: contribution.id, goalID: contribution.goal?.id ?? UUID(), amountMinor: contribution.amountMinor, date: contribution.date, notes: contribution.notes, createdAt: contribution.createdAt, transactionID: contribution.transaction?.id)
    }

    private static func debtDTO(_ debt: Debt) -> DebtDTO {
        DebtDTO(id: debt.id, person: debt.person, direction: debt.directionRaw, originalMinor: debt.originalMinor, currencyCode: debt.currencyCode, dueDate: debt.dueDate, interestRateText: debt.interestRateText, notes: debt.notes, isWrittenOff: debt.isWrittenOff, reminderEnabled: debt.reminderEnabled, createdAt: debt.createdAt, updatedAt: debt.updatedAt, accountID: debt.account?.id)
    }

    private static func repaymentDTO(_ repayment: DebtRepayment) -> RepaymentDTO {
        RepaymentDTO(id: repayment.id, debtID: repayment.debt?.id ?? UUID(), amountMinor: repayment.amountMinor, date: repayment.date, notes: repayment.notes, createdAt: repayment.createdAt, transactionID: repayment.transaction?.id)
    }

    private static func zakatDTO(_ record: ZakatCalculationRecord) -> ZakatCalculationDTO {
        ZakatCalculationDTO(id: record.id, createdAt: record.createdAt, currencyCode: record.currencyCode, methodRaw: record.methodRaw, hawlConfirmed: record.hawlConfirmed, hawlDate: record.hawlDate, cashHomeMinor: record.cashHomeMinor, bankMinor: record.bankMinor, investmentsMinor: record.investmentsMinor, moneyLentMinor: record.moneyLentMinor, receivablesMinor: record.receivablesMinor, businessCashMinor: record.businessCashMinor, inventoryMinor: record.inventoryMinor, otherAssetsMinor: record.otherAssetsMinor, includeRetirement: record.includeRetirement, retirementMinor: record.retirementMinor, shortTermLiabilitiesMinor: record.shortTermLiabilitiesMinor, paidInAdvanceMinor: record.paidInAdvanceMinor, goldGrams: record.goldGrams, goldKarat: record.goldKarat, goldPricePerGramMinor: record.goldPricePerGramMinor, goldPriceSource: record.goldPriceSource, goldPriceDate: record.goldPriceDate, silverGrams: record.silverGrams, silverFineness: record.silverFineness, silverPricePerGramMinor: record.silverPricePerGramMinor, silverPriceSource: record.silverPriceSource, silverPriceDate: record.silverPriceDate, eligibleAssetsMinor: record.eligibleAssetsMinor, deductionsMinor: record.deductionsMinor, netWealthMinor: record.netWealthMinor, nisabMinor: record.nisabMinor, nisabKnown: record.nisabKnown, zakatDueMinor: record.zakatDueMinor, remainingMinor: record.remainingMinor, statusRaw: record.statusRaw, notes: record.notes, engineVersion: record.engineVersion)
    }

    private static func charityDTO(_ record: CharityRecord) -> CharityRecordDTO {
        CharityRecordDTO(id: record.id, kindRaw: record.kindRaw, amountMinor: record.amountMinor, currencyCode: record.currencyCode, date: record.date, recipient: record.recipient, notes: record.notes, receiptBase64: record.receiptImage?.base64EncodedString(), transactionID: record.transactionID, calculationID: record.calculationID, createdAt: record.createdAt)
    }

    private static func charityGoalDTO(_ goal: CharityGoal) -> CharityGoalDTO {
        CharityGoalDTO(id: goal.id, name: goal.name, cadenceRaw: goal.cadenceRaw, donationKindRaw: goal.donationKindRaw, targetMinor: goal.targetMinor, currencyCode: goal.currencyCode, startDate: goal.startDate, endDate: goal.endDate)
    }

    private static func ramadanDTO(_ plan: RamadanPlan) -> RamadanPlanDTO {
        RamadanPlanDTO(id: plan.id, hijriYear: plan.hijriYear, startDate: plan.startDate, endDate: plan.endDate, currencyCode: plan.currencyCode, savingsTargetMinor: plan.savingsTargetMinor, linesJSON: plan.linesJSON)
    }

    private static func ramadanLinkDTO(_ link: RamadanLink) -> RamadanLinkDTO {
        RamadanLinkDTO(id: link.id, planID: link.planID, lineID: link.lineID, transactionID: link.transactionID)
    }
}
