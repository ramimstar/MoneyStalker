import SwiftData
import XCTest
@testable import MoneyStalker

@MainActor
final class PersistenceTests: XCTestCase {
    func testCreateEditAndDeleteUpdateBalances() throws {
        let store = try TestBox()
        let cash = Account(name: "Cash", type: .cash, openingBalanceMinor: 10_000, currencyCode: "BDT", icon: "banknote", colorHex: "0E6B52")
        let bank = Account(name: "Bank", type: .bank, openingBalanceMinor: 0, currencyCode: "BDT", icon: "building.columns", colorHex: "10243A")
        let food = Category(name: "Food", kind: .expense, icon: "fork.knife", colorHex: "D85745")
        let salary = Category(name: "Salary", kind: .income, icon: "banknote", colorHex: "1B7F45")
        store.context.insert(cash)
        store.context.insert(bank)
        store.context.insert(food)
        store.context.insert(salary)
        let income = try TransactionWriter.create(draft: draft(5_000, .income, cash, category: salary), account: cash, counterAccount: nil, category: salary, subcategory: nil, receipt: nil, context: store.context, existing: [], allowDuplicate: true)
        _ = try TransactionWriter.create(draft: draft(2_000, .expense, cash, category: food), account: cash, counterAccount: nil, category: food, subcategory: nil, receipt: nil, context: store.context, existing: [], allowDuplicate: true)
        _ = try TransactionWriter.create(draft: draft(1_000, .transfer, cash, counter: bank), account: cash, counterAccount: bank, category: nil, subcategory: nil, receipt: nil, context: store.context, existing: [], allowDuplicate: true)
        XCTAssertEqual(balance(cash, store), 12_000)
        XCTAssertEqual(balance(bank, store), 1_000)
        XCTAssertEqual(flow(store).incomeMinor, 5_000)
        XCTAssertEqual(flow(store).expenseMinor, 2_000)
        var edited = draft(8_000, .income, cash, category: salary)
        edited.editingID = income.id
        try TransactionWriter.update(income, draft: edited, account: cash, counterAccount: nil, category: salary, subcategory: nil, receipt: nil, context: store.context)
        XCTAssertEqual(balance(cash, store), 15_000)
        let expense = try store.context.fetch(FetchDescriptor<LedgerTransaction>()).first { $0.type == .expense }!
        try TransactionWriter.delete(expense, context: store.context)
        XCTAssertEqual(balance(cash, store), 17_000)
        XCTAssertEqual(flow(store).expenseMinor, 0)
    }

    func testDebtPrincipalAndInterestStayClassified() throws {
        let store = try TestBox()
        let cash = Account(name: "Cash", type: .cash, openingBalanceMinor: 0, currencyCode: "BDT", icon: "banknote", colorHex: "0E6B52")
        let interest = Category(name: "Loan Interest", kind: .expense, icon: "percent", colorHex: "5C6770")
        store.context.insert(cash)
        store.context.insert(interest)
        let debt = try DebtWriter.create(person: "Sam", direction: .borrowed, amountMinor: 100_000, currencyCode: "BDT", account: cash, dueDate: nil, interestRateText: "5", notes: "", reminder: false, date: .now, context: store.context)
        XCTAssertEqual(balance(cash, store), 100_000)
        XCTAssertEqual(flow(store).incomeMinor, 0)
        try DebtWriter.repay(debt: debt, amountMinor: 40_000, account: cash, date: .now, notes: "", context: store.context)
        let outstanding = DebtMath.summary(debt: debt.snapshot, repayments: debt.repayments.map(\.snapshot)).outstandingMinor
        XCTAssertEqual(outstanding, 60_000)
        XCTAssertEqual(balance(cash, store), 60_000)
        XCTAssertEqual(flow(store).expenseMinor, 0)
        try DebtWriter.recordInterest(debt: debt, amountMinor: 2_500, account: cash, category: interest, date: .now, notes: "", context: store.context)
        XCTAssertEqual(flow(store).expenseMinor, 2_500)
        XCTAssertEqual(balance(cash, store), 57_500)
        try DebtWriter.delete(debt: debt, context: store.context)
        XCTAssertEqual(balance(cash, store), 0)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<LedgerTransaction>()).count, 0)
    }

    func testSavingsTransferIsNotIncome() throws {
        let store = try TestBox()
        let cash = Account(name: "Cash", type: .cash, openingBalanceMinor: 50_000, currencyCode: "BDT", icon: "banknote", colorHex: "0E6B52")
        let savings = Account(name: "Savings", type: .savings, openingBalanceMinor: 0, currencyCode: "BDT", icon: "leaf", colorHex: "1B7F45")
        let goal = SavingsGoal(name: "Trip", targetMinor: 40_000, currencyCode: "BDT")
        store.context.insert(cash)
        store.context.insert(savings)
        store.context.insert(goal)
        try GoalWriter.addContribution(goal: goal, amountMinor: 10_000, date: .now, notes: "", from: cash, to: savings, context: store.context)
        try GoalWriter.addContribution(goal: goal, amountMinor: 5_000, date: .now, notes: "Already saved", from: nil, to: nil, context: store.context)
        XCTAssertEqual(flow(store).incomeMinor, 0)
        XCTAssertEqual(balance(cash, store), 40_000)
        XCTAssertEqual(balance(savings, store), 10_000)
        let progress = GoalMath.progress(goal: goal.snapshot, contributions: goal.contributions.map(\.snapshot))
        XCTAssertEqual(progress.currentMinor, 15_000)
        let linked = goal.contributions.first { $0.transaction != nil }!
        try GoalWriter.deleteContribution(linked, context: store.context)
        XCTAssertEqual(balance(cash, store), 50_000)
        XCTAssertEqual(balance(savings, store), 0)
    }

    func testRecurringProcessingDoesNotDuplicate() throws {
        let store = try TestBox()
        let calendar = TestDates.calendar()
        let when = TestDates.date(2024, 5, 1, calendar: calendar)
        let cash = Account(name: "Cash", type: .cash, openingBalanceMinor: 0, currencyCode: "BDT", icon: "banknote", colorHex: "0E6B52")
        let rent = Category(name: "Housing", kind: .expense, icon: "house", colorHex: "8C5A3C")
        store.context.insert(cash)
        store.context.insert(rent)
        let rule = RecurringRule(name: "Rent", amountMinor: 15_000, type: .expense, currencyCode: "BDT", destinationCurrencyCode: "BDT", frequency: .monthly, startDate: when, nextOccurrence: when)
        store.context.insert(rule)
        rule.account = cash
        rule.category = rent
        try store.context.save()
        XCTAssertEqual(try RecurringProcessor.process(context: store.context, now: when, calendar: calendar), 1)
        XCTAssertEqual(try RecurringProcessor.process(context: store.context, now: when, calendar: calendar), 0)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<LedgerTransaction>()).count, 1)
        rule.nextOccurrence = when
        rule.processedOccurrenceKeys = []
        try store.context.save()
        XCTAssertEqual(try RecurringProcessor.process(context: store.context, now: when, calendar: calendar), 0)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<LedgerTransaction>()).count, 1)
    }

    func testYearlyLeapRuleAdvancesWithoutDuplicating() throws {
        let store = try TestBox()
        let calendar = TestDates.calendar()
        let leap = TestDates.date(2024, 2, 29, calendar: calendar)
        let now = TestDates.date(2024, 3, 1, calendar: calendar)
        let cash = Account(name: "Cash", type: .cash, openingBalanceMinor: 0, currencyCode: "BDT", icon: "banknote", colorHex: "0E6B52")
        let gift = Category(name: "Gifts", kind: .income, icon: "gift", colorHex: "B4536A")
        store.context.insert(cash)
        store.context.insert(gift)
        let rule = RecurringRule(name: "Annual", amountMinor: 1_000, type: .income, currencyCode: "BDT", destinationCurrencyCode: "BDT", frequency: .yearly, startDate: leap, nextOccurrence: leap)
        store.context.insert(rule)
        rule.account = cash
        rule.category = gift
        try store.context.save()
        XCTAssertEqual(try RecurringProcessor.process(context: store.context, now: now, calendar: calendar), 1)
        XCTAssertEqual(calendar.component(.year, from: rule.nextOccurrence), 2025)
        XCTAssertEqual(calendar.component(.month, from: rule.nextOccurrence), 2)
        XCTAssertEqual(calendar.component(.day, from: rule.nextOccurrence), 28)
        XCTAssertEqual(try RecurringProcessor.process(context: store.context, now: now, calendar: calendar), 0)
    }

    func testBackupRoundTripRestoresBalances() throws {
        let source = try TestBox()
        let defaults = UserDefaults(suiteName: "moneyStalker.tests.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.currencyCode = "BDT"
        let cash = Account(name: "Cash", type: .cash, openingBalanceMinor: 7_500, currencyCode: "BDT", icon: "banknote", colorHex: "0E6B52", notes: "Wallet")
        let food = Category(name: "Food", kind: .expense, icon: "fork.knife", colorHex: "D85745")
        source.context.insert(cash)
        source.context.insert(food)
        _ = try TransactionWriter.create(draft: draft(1_250, .expense, cash, category: food, notes: "Lunch, \"special\""), account: cash, counterAccount: nil, category: food, subcategory: nil, receipt: Data([1, 2, 3]), context: source.context, existing: [], allowDuplicate: true)
        let budget = Budget(name: "Monthly", kind: .monthly, limitMinor: 20_000, currencyCode: "BDT", startDate: .now, category: food)
        source.context.insert(budget)
        try source.context.save()
        let data = try BackupService.exportData(context: source.context, settings: settings)
        let destination = try TestBox()
        let restoredDefaults = UserDefaults(suiteName: "moneyStalker.tests.\(UUID().uuidString)")!
        let restoredSettings = SettingsStore(defaults: restoredDefaults)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try BackupService.restore(data: data, context: destination.context, settings: restoredSettings, directory: directory)
        let accounts = try destination.context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(balance(accounts[0], destination), 6_250)
        XCTAssertEqual(try destination.context.fetch(FetchDescriptor<LedgerTransaction>()).first?.receiptImage, Data([1, 2, 3]))
        XCTAssertEqual(restoredSettings.currencyCode, "BDT")
        XCTAssertFalse(RestoreGuard.needsRecovery(directory: directory))
        var tampered = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        tampered["formatVersion"] = 99
        let bad = try JSONSerialization.data(withJSONObject: tampered)
        XCTAssertThrowsError(try BackupCodec.decode(bad))
    }

    private func draft(_ amount: Int64, _ type: TransactionType, _ account: Account, counter: Account? = nil, category: MoneyStalker.Category? = nil, notes: String = "") -> TransactionDraft {
        TransactionDraft(amountMinor: amount, destinationAmountMinor: amount, type: type, accountID: account.id, counterAccountID: counter?.id, categoryID: category?.id, date: .now, notes: notes, tags: [], sourceCurrencyCode: account.currencyCode, destinationCurrencyCode: counter?.currencyCode)
    }

    private func balance(_ account: Account, _ store: TestBox) -> Int64 {
        let transactions = (try? store.context.fetch(FetchDescriptor<LedgerTransaction>())) ?? []
        return LedgerCalculator.balanceMinor(for: account.snapshot, transactions: transactions.map(\.snapshot))
    }

    private func flow(_ store: TestBox) -> CashflowTotals {
        let transactions = (try? store.context.fetch(FetchDescriptor<LedgerTransaction>())) ?? []
        return LedgerCalculator.cashflow(transactions: transactions.map(\.snapshot), window: nil, currencyCode: "BDT")
    }
}

@MainActor
final class TestBox {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    init() throws { container = try ModelContainerFactory.make(inMemory: true) }
}
