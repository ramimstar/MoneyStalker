import XCTest
@testable import MoneyStalker

final class BudgetAndCalendarTests: XCTestCase {
    func testBudgetIgnoresIncomeAndTransfers() {
        let calendar = TestDates.calendar()
        let food = UUID()
        let categories = [TestFixtures.category(id: food, name: "Food")]
        let cash = TestFixtures.account()
        let bank = TestFixtures.account()
        let start = TestDates.date(2024, 1, 1, calendar: calendar)
        let now = TestDates.date(2024, 1, 15, calendar: calendar)
        let budget = BudgetSnapshot(id: UUID(), name: "Food", kind: .monthly, limitMinor: 10_000, currencyCode: "BDT", startDate: start, endDate: nil, warningThresholdBasisPoints: 8_000, rollover: false, isArchived: false, categoryID: food)
        let transactions = [
            TestFixtures.transaction(amount: 3_000, type: .expense, account: cash.id, category: food, date: TestDates.date(2024, 1, 10, calendar: calendar)),
            TestFixtures.transaction(amount: 9_000, type: .income, account: cash.id, date: TestDates.date(2024, 1, 10, calendar: calendar)),
            TestFixtures.transaction(amount: 4_000, type: .transfer, account: cash.id, counter: bank.id, date: TestDates.date(2024, 1, 11, calendar: calendar))
        ]
        let status = BudgetEngine.status(budget: budget, transactions: transactions, categories: categories, now: now, calendar: calendar)
        XCTAssertEqual(status.spentMinor, 3_000)
        XCTAssertEqual(status.remainingMinor, 7_000)
        XCTAssertFalse(status.isOverBudget)
    }

    func testBudgetRolloverCarriesUnderspendAndOverspend() {
        let calendar = TestDates.calendar()
        let start = TestDates.date(2024, 1, 1, calendar: calendar)
        let now = TestDates.date(2024, 2, 10, calendar: calendar)
        let cash = TestFixtures.account()
        let budget = BudgetSnapshot(id: UUID(), name: "All", kind: .monthly, limitMinor: 10_000, currencyCode: "BDT", startDate: start, endDate: nil, warningThresholdBasisPoints: 8_000, rollover: true, isArchived: false, categoryID: nil)
        let transactions = [
            TestFixtures.transaction(amount: 4_000, type: .expense, account: cash.id, date: TestDates.date(2024, 1, 20, calendar: calendar)),
            TestFixtures.transaction(amount: 3_000, type: .expense, account: cash.id, date: TestDates.date(2024, 2, 5, calendar: calendar))
        ]
        let status = BudgetEngine.status(budget: budget, transactions: transactions, categories: [], now: now, calendar: calendar)
        XCTAssertEqual(status.availableMinor, 16_000)
        XCTAssertEqual(status.spentMinor, 3_000)
        XCTAssertEqual(status.previousSpentMinor, 4_000)
        XCTAssertEqual(status.remainingMinor, 13_000)
    }

    func testSubcategoryCountsTowardParentBudgetOnly() {
        let parent = UUID()
        let child = UUID()
        let other = UUID()
        let categories = [
            TestFixtures.category(id: parent, name: "Food"),
            TestFixtures.category(id: child, name: "Groceries", parent: parent),
            TestFixtures.category(id: other, name: "Transport")
        ]
        let cash = TestFixtures.account()
        let window = DateWindow(start: .distantPast, end: .distantFuture)
        let budget = BudgetSnapshot(id: UUID(), name: "Food", kind: .monthly, limitMinor: 5_000, currencyCode: "BDT", startDate: .distantPast, endDate: nil, warningThresholdBasisPoints: 8_000, rollover: false, isArchived: false, categoryID: parent)
        let transactions = [
            TestFixtures.transaction(amount: 1_000, type: .expense, account: cash.id, subcategory: child),
            TestFixtures.transaction(amount: 700, type: .expense, account: cash.id, category: other)
        ]
        XCTAssertEqual(BudgetEngine.spentMinor(budget: budget, window: window, transactions: transactions, categories: categories), 1_000)
    }

    func testFebruary2024Has29DaysAndWeekStartChangesLeadingCells() {
        let sunday = TestDates.calendar(firstWeekday: 1)
        let monday = TestDates.calendar(firstWeekday: 2)
        let month = TestDates.date(2024, 2, 1, calendar: sunday)
        let sundayCells = MonthGridBuilder.cells(for: month, calendar: sunday)
        let mondayCells = MonthGridBuilder.cells(for: month, calendar: monday)
        let sundayDays = sundayCells.compactMap(\.date)
        XCTAssertEqual(sundayDays.count, 29)
        XCTAssertEqual(sunday.component(.day, from: sundayDays.last!), 29)
        XCTAssertEqual(sunday.component(.weekday, from: sundayDays[0]), 5)
        XCTAssertNil(sundayCells[3].date)
        XCTAssertNotNil(sundayCells[4].date)
        XCTAssertNil(mondayCells[2].date)
        XCTAssertNotNil(mondayCells[3].date)
        let february2025 = MonthGridBuilder.cells(for: TestDates.date(2025, 2, 1, calendar: sunday), calendar: sunday).compactMap(\.date)
        XCTAssertEqual(february2025.count, 28)
    }

    func testMonthAndYearBoundaries() {
        let calendar = TestDates.calendar()
        let jan31 = TestDates.date(2024, 1, 31, calendar: calendar)
        let feb29 = RecurrenceCalendar.nextDate(after: jan31, frequency: .monthly, interval: 1, calendar: calendar)!
        XCTAssertEqual(calendar.component(.month, from: feb29), 2)
        XCTAssertEqual(calendar.component(.day, from: feb29), 29)
        let mar31 = TestDates.date(2024, 3, 31, calendar: calendar)
        let apr30 = RecurrenceCalendar.nextDate(after: mar31, frequency: .monthly, interval: 1, calendar: calendar)!
        XCTAssertEqual(calendar.component(.month, from: apr30), 4)
        XCTAssertEqual(calendar.component(.day, from: apr30), 30)
        let leap = TestDates.date(2024, 2, 29, calendar: calendar)
        let nextYear = RecurrenceCalendar.nextDate(after: leap, frequency: .yearly, interval: 1, calendar: calendar)!
        XCTAssertEqual(calendar.component(.year, from: nextYear), 2025)
        XCTAssertEqual(calendar.component(.month, from: nextYear), 2)
        XCTAssertEqual(calendar.component(.day, from: nextYear), 28)
    }
}
