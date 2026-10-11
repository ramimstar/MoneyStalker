import XCTest
@testable import MoneyStalker

final class LedgerCalculatorTests: XCTestCase {
    func testOpeningIncomeAndExpense() {
        let cash = TestFixtures.account(opening: 10_000)
        let transactions = [
            TestFixtures.transaction(amount: 2_000, type: .income, account: cash.id),
            TestFixtures.transaction(amount: 500, type: .expense, account: cash.id)
        ]
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: cash, transactions: transactions), 11_500)
        let totals = LedgerCalculator.cashflow(transactions: transactions, window: nil, currencyCode: "BDT")
        XCTAssertEqual(totals.incomeMinor, 2_000)
        XCTAssertEqual(totals.expenseMinor, 500)
        XCTAssertEqual(totals.netMinor, 1_500)
    }

    func testTransferIsNotIncomeOrExpense() {
        let cash = TestFixtures.account(name: "Cash", opening: 10_000)
        let bank = TestFixtures.account(name: "Bank")
        let transfer = TestFixtures.transaction(amount: 1_500, type: .transfer, account: cash.id, counter: bank.id)
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: cash, transactions: [transfer]), 8_500)
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: bank, transactions: [transfer]), 1_500)
        let totals = LedgerCalculator.cashflow(transactions: [transfer], window: nil, currencyCode: "BDT")
        XCTAssertEqual(totals.incomeMinor, 0)
        XCTAssertEqual(totals.expenseMinor, 0)
    }

    func testCrossCurrencyTransferUsesBothAmounts() {
        let taka = TestFixtures.account(opening: 20_000, currency: "BDT")
        let dollars = TestFixtures.account(currency: "USD")
        let transfer = TestFixtures.transaction(amount: 11_750, type: .transfer, account: taka.id, counter: dollars.id, destination: 10_000, currency: "BDT", destinationCurrency: "USD")
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: taka, transactions: [transfer]), 8_250)
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: dollars, transactions: [transfer]), 10_000)
    }

    func testPrincipalIsExcludedFromIncomeAndExpense() {
        let cash = TestFixtures.account(opening: 0)
        let inbound = TestFixtures.transaction(amount: 50_000, type: .principal, account: cash.id, direction: .inbound)
        let outbound = TestFixtures.transaction(amount: 20_000, type: .principal, account: cash.id, direction: .outbound)
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: cash, transactions: [inbound, outbound]), 30_000)
        let totals = LedgerCalculator.cashflow(transactions: [inbound, outbound], window: nil, currencyCode: "BDT")
        XCTAssertEqual(totals.incomeMinor, 0)
        XCTAssertEqual(totals.expenseMinor, 0)
    }

    func testCreditCardSignedBalanceAndNetWorth() {
        let card = TestFixtures.account(name: "Card", type: .credit, opening: -50_000)
        let cash = TestFixtures.account(name: "Cash", opening: 100_000)
        let purchase = TestFixtures.transaction(amount: 2_000, type: .expense, account: card.id)
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: card, transactions: [purchase]), -52_000)
        let summary = LedgerCalculator.netWorth(accounts: [card, cash], transactions: [purchase], preferredCurrency: "BDT", rates: [:], includeArchived: true)
        XCTAssertEqual(summary.displayMinor, 48_000)
        XCTAssertEqual(summary.displayCurrency, "BDT")
    }

    func testMixedCurrenciesAreNotAddedWithoutARate() {
        let taka = TestFixtures.account(opening: 10_000, currency: "BDT")
        let dollars = TestFixtures.account(opening: 500, currency: "USD")
        let missing = LedgerCalculator.netWorth(accounts: [taka, dollars], transactions: [], preferredCurrency: "BDT", rates: [:], includeArchived: true)
        XCTAssertNil(missing.displayMinor)
        XCTAssertEqual(missing.missingRateCurrencies, ["USD"])
        let rates = ["USD": Decimal(string: "110")!]
        let converted = LedgerCalculator.netWorth(accounts: [taka, dollars], transactions: [], preferredCurrency: "BDT", rates: rates, includeArchived: true)
        XCTAssertEqual(converted.displayCurrency, "BDT")
        XCTAssertEqual(converted.displayMinor, 10_000 + 55_000)
    }

    func testArchivedAccountRemainsInNetWorth() {
        let archived = TestFixtures.account(opening: 4_000, archived: true)
        let included = LedgerCalculator.netWorth(accounts: [archived], transactions: [], preferredCurrency: "BDT", rates: [:], includeArchived: true)
        let excluded = LedgerCalculator.netWorth(accounts: [archived], transactions: [], preferredCurrency: "BDT", rates: [:], includeArchived: false)
        XCTAssertEqual(included.displayMinor, 4_000)
        XCTAssertEqual(excluded.displayMinor, 0)
    }

    func testDeletingATransactionRemovesItFromTheBalance() {
        let cash = TestFixtures.account(opening: 1_000)
        let expense = TestFixtures.transaction(amount: 400, type: .expense, account: cash.id)
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: cash, transactions: [expense]), 600)
        XCTAssertEqual(LedgerCalculator.balanceMinor(for: cash, transactions: []), 1_000)
    }

    func testEmptyDatabaseIsZero() {
        let totals = LedgerCalculator.cashflow(transactions: [], window: nil, currencyCode: "BDT")
        XCTAssertEqual(totals.incomeMinor, 0)
        XCTAssertEqual(totals.expenseMinor, 0)
        XCTAssertNil(totals.savingsRateBasisPoints)
        let worth = LedgerCalculator.netWorth(accounts: [], transactions: [], preferredCurrency: "BDT", rates: [:], includeArchived: true)
        XCTAssertEqual(worth.displayMinor, 0)
    }

    func testSavingsRateUsesIntegerMinorUnits() {
        let cash = TestFixtures.account()
        let transactions = [
            TestFixtures.transaction(amount: 10_000, type: .income, account: cash.id),
            TestFixtures.transaction(amount: 2_500, type: .expense, account: cash.id)
        ]
        let totals = LedgerCalculator.cashflow(transactions: transactions, window: nil, currencyCode: "BDT")
        XCTAssertEqual(totals.savingsRateBasisPoints, 7_500)
    }

    func testDateWindowIncludesTheWholeEndDay() {
        let calendar = TestDates.calendar()
        let window = DateWindow.covering(startDay: TestDates.date(2024, 3, 1, calendar: calendar), endDay: TestDates.date(2024, 3, 31, calendar: calendar), calendar: calendar)
        XCTAssertTrue(window.contains(TestDates.date(2024, 3, 31, 23, calendar: calendar)))
        XCTAssertFalse(window.contains(TestDates.date(2024, 4, 1, 0, calendar: calendar)))
        let cash = TestFixtures.account()
        let inside = TestFixtures.transaction(amount: 100, type: .expense, account: cash.id, date: TestDates.date(2024, 3, 31, 23, calendar: calendar))
        let outside = TestFixtures.transaction(amount: 900, type: .expense, account: cash.id, date: TestDates.date(2024, 4, 1, 0, calendar: calendar))
        let totals = LedgerCalculator.cashflow(transactions: [inside, outside], window: window, currencyCode: "BDT")
        XCTAssertEqual(totals.expenseMinor, 100)
    }

    func testCategoryRollupIncludesSubcategory() {
        let parent = UUID()
        let child = UUID()
        let categories = [
            TestFixtures.category(id: parent, name: "Food"),
            TestFixtures.category(id: child, name: "Groceries", parent: parent)
        ]
        let cash = TestFixtures.account()
        let expense = TestFixtures.transaction(amount: 800, type: .expense, account: cash.id, category: parent, subcategory: child)
        let totals = LedgerCalculator.categoryTotals(transactions: [expense], categories: categories, kind: .expense, window: nil, currencyCode: "BDT", rollUpToParent: true)
        XCTAssertEqual(totals.first?.id, parent)
        XCTAssertEqual(totals.first?.amountMinor, 800)
    }
}
