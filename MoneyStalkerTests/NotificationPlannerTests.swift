import XCTest
@testable import MoneyStalker

final class NotificationPlannerTests: XCTestCase {
    private let calendar = TestDates.calendar(firstWeekday: 1)

    func testMasterSwitchCancelsEveryPlan() {
        var context = sample()
        context.preferences.enabled = false
        let plan = NotificationPlanner.plan(context: context, now: TestDates.date(2024, 1, 15, calendar: calendar), calendar: calendar)
        XCTAssertTrue(plan.pending.isEmpty)
        XCTAssertTrue(plan.immediate.isEmpty)
    }

    func testBudgetThresholdFiresOncePerPeriod() {
        let now = TestDates.date(2024, 1, 15, calendar: calendar)
        var context = sample()
        context.budgets = [budget(name: "Food", spent: 8_000, consumed: 8_000, over: false)]
        let first = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        XCTAssertEqual(first.immediate.count, 1)
        XCTAssertTrue(first.immediate[0].body.contains("Food"))
        XCTAssertTrue(first.immediate[0].body.contains("80%"))
        XCTAssertFalse(first.immediate[0].body.contains("gone over"))

        context.claims = first.claims
        let second = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        XCTAssertTrue(second.immediate.isEmpty)
    }

    func testBudgetOverageUsesExceededWording() {
        var context = sample()
        context.budgets = [budget(name: "Food", spent: 11_000, consumed: 11_000, over: true)]
        let plan = NotificationPlanner.plan(context: context, now: TestDates.date(2024, 1, 15, calendar: calendar), calendar: calendar)
        XCTAssertEqual(plan.immediate.count, 1)
        XCTAssertTrue(plan.immediate[0].body.contains("gone over"))
    }

    func testDroppedBudgetCanAlertAgain() {
        let now = TestDates.date(2024, 1, 15, calendar: calendar)
        var context = sample()
        let high = budget(name: "Food", spent: 8_000, consumed: 8_000, over: false)
        context.budgets = [high]
        let first = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        context.claims = first.claims
        var lower = high
        lower.spentMinor = 1_000
        lower.consumedBasisPoints = 1_000
        lower.remainingMinor = 9_000
        lower.isWarning = false
        context.budgets = [lower]
        let cleared = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        XCTAssertTrue(cleared.immediate.isEmpty)
        context.claims = cleared.claims
        context.budgets = [high]
        let again = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        XCTAssertEqual(again.immediate.count, 1)
    }

    func testDailySummaryUsesRealCashflowAndSkipsTransfers() {
        let now = TestDates.date(2024, 1, 15, calendar: calendar)
        var context = sample()
        context.preferences.smart.dailySummaryEnabled = true
        context.preferences.smart.dailySummaryMinutes = 21 * 60
        let account = UUID()
        context.transactions = [
            TestFixtures.transaction(amount: 200_000, type: .income, account: account, date: TestDates.date(2024, 1, 15, 9, calendar: calendar)),
            TestFixtures.transaction(amount: 125_000, type: .expense, account: account, date: TestDates.date(2024, 1, 15, 10, calendar: calendar)),
            TestFixtures.transaction(amount: 50_000, type: .transfer, account: account, counter: UUID(), date: TestDates.date(2024, 1, 15, 11, calendar: calendar))
        ]
        let plan = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        let summary = plan.pending.first { $0.identifier == "moneyStalker.summary.daily" }
        XCTAssertEqual(summary?.title, "Your Daily Money Summary 📊")
        XCTAssertTrue(summary?.body.contains("2,000.00") == true)
        XCTAssertTrue(summary?.body.contains("1,250.00") == true)
        XCTAssertFalse(summary?.body.contains("500.00") == true)
    }

    func testDailySummaryWaitsUntilTheSameDay() {
        let now = TestDates.date(2024, 1, 15, 22, calendar: calendar)
        var context = sample()
        context.preferences.smart.dailySummaryEnabled = true
        context.preferences.smart.dailySummaryMinutes = 21 * 60
        let plan = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        XCTAssertNil(plan.pending.first { $0.identifier == "moneyStalker.summary.daily" })
    }

    func testExpenseReminderSkipsADayThatAlreadyHasExpenses() {
        let now = TestDates.date(2024, 1, 15, 12, calendar: calendar)
        var context = sample()
        context.transactions = [
            TestFixtures.transaction(amount: 100, type: .expense, account: UUID(), date: TestDates.date(2024, 1, 15, 9, calendar: calendar))
        ]
        let plan = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        let reminder = plan.pending.first { $0.identifier == "moneyStalker.expense.reminder" }
        let fire = reminder?.fireDate ?? .distantPast
        XCTAssertEqual(calendar.component(.day, from: fire), 16)
        XCTAssertEqual(reminder?.repeatRule, NotificationRepeat.none)
    }

    func testSettledBillIsNotScheduled() {
        var context = sample()
        context.debts = [DebtReminderInput(id: UUID(), name: "Rent", amountMinor: 0, currencyCode: "BDT", dueDate: TestDates.date(2024, 1, 20, calendar: calendar), isOpen: false)]
        let plan = NotificationPlanner.plan(context: context, now: TestDates.date(2024, 1, 15, calendar: calendar), calendar: calendar)
        XCTAssertNil(plan.pending.first { $0.identifier.hasPrefix("moneyStalker.bill.") })
    }

    func testOpenBillUsesOutstandingAmount() {
        var context = sample()
        context.debts = [DebtReminderInput(id: UUID(), name: "Rent", amountMinor: 250_000, currencyCode: "BDT", dueDate: TestDates.date(2024, 1, 20, calendar: calendar), isOpen: true)]
        let plan = NotificationPlanner.plan(context: context, now: TestDates.date(2024, 1, 15, calendar: calendar), calendar: calendar)
        let bill = plan.pending.first { $0.identifier.hasPrefix("moneyStalker.bill.") }
        XCTAssertEqual(bill?.title, "Upcoming Bill Reminder 📅")
        XCTAssertTrue(bill?.body.contains("Rent") == true)
        XCTAssertTrue(bill?.body.contains("2,500.00") == true)
    }

    func testSavingsMilestoneDoesNotRepeat() {
        let goal = GoalProgress(id: UUID(), name: "Trip", icon: "flag", colorHex: "0E6B52", targetMinor: 100, currentMinor: 100, remainingMinor: 0, currencyCode: "BDT", targetDate: nil, basisPoints: 10_000, isComplete: true)
        var context = sample()
        context.goals = [goal]
        let first = NotificationPlanner.plan(context: context, now: TestDates.date(2024, 1, 15, calendar: calendar), calendar: calendar)
        XCTAssertEqual(first.immediate.filter { $0.title.contains("Savings") }.count, 1)
        context.claims = first.claims
        let second = NotificationPlanner.plan(context: context, now: TestDates.date(2024, 1, 15, calendar: calendar), calendar: calendar)
        XCTAssertTrue(second.immediate.filter { $0.title.contains("Savings") }.isEmpty)
    }

    func testUnusualSpendingNeedsThreeEarlierMonths() {
        let food = UUID()
        let account = UUID()
        var context = sample()
        context.preferences.smart.unusualSpendingEnabled = true
        context.categories = [TestFixtures.category(id: food, name: "Food")]
        context.transactions = [
            TestFixtures.transaction(amount: 1_000, type: .expense, account: account, category: food, date: TestDates.date(2023, 10, 5, calendar: calendar)),
            TestFixtures.transaction(amount: 1_000, type: .expense, account: account, category: food, date: TestDates.date(2023, 11, 5, calendar: calendar)),
            TestFixtures.transaction(amount: 4_000, type: .expense, account: account, category: food, date: TestDates.date(2024, 1, 5, calendar: calendar))
        ]
        let tooSoon = NotificationPlanner.plan(context: context, now: TestDates.date(2024, 1, 15, calendar: calendar), calendar: calendar)
        XCTAssertTrue(tooSoon.immediate.filter { $0.title.contains("Unusual") }.isEmpty)

        context.transactions.append(TestFixtures.transaction(amount: 1_000, type: .expense, account: account, category: food, date: TestDates.date(2023, 12, 5, calendar: calendar)))
        let ready = NotificationPlanner.plan(context: context, now: TestDates.date(2024, 1, 15, calendar: calendar), calendar: calendar)
        XCTAssertEqual(ready.immediate.filter { $0.title.contains("Unusual") }.count, 1)
        XCTAssertTrue(ready.immediate.contains { $0.body.contains("Food") })
    }

    func testInactivityDoesNotRepeatTheSameGap() {
        var context = sample()
        context.preferences.smart.inactivityEnabled = true
        context.preferences.smart.inactivityDays = 3
        context.transactions = [TestFixtures.transaction(amount: 100, type: .expense, account: UUID(), date: TestDates.date(2024, 1, 1, calendar: calendar))]
        let now = TestDates.date(2024, 1, 10, calendar: calendar)
        let first = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        XCTAssertEqual(first.pending.filter { $0.identifier.hasPrefix("moneyStalker.claim.idle.") }.count, 1)
        context.claims = first.claims
        let second = NotificationPlanner.plan(context: context, now: now, calendar: calendar)
        XCTAssertTrue(second.pending.filter { $0.identifier.hasPrefix("moneyStalker.claim.idle.") }.isEmpty)
    }

    private func sample() -> NotificationContext {
        NotificationContext(
            preferences: NotificationPreferences(
                enabled: true,
                budgetAlertsEnabled: true,
                recurringRemindersEnabled: true,
                billRemindersEnabled: true,
                smart: SmartNotificationSettings()
            ),
            currencyCode: "BDT",
            transactions: [],
            categories: [],
            budgets: [],
            goals: [],
            debts: [],
            rules: [],
            claims: []
        )
    }

    private func budget(name: String, spent: Int64, consumed: Int64, over: Bool) -> BudgetStatus {
        let start = TestDates.date(2024, 1, 1, calendar: calendar)
        return BudgetStatus(
            id: UUID(),
            name: name,
            currencyCode: "BDT",
            limitMinor: 10_000,
            spentMinor: spent,
            availableMinor: 10_000,
            remainingMinor: 10_000 - spent,
            consumedBasisPoints: consumed,
            isOverBudget: over,
            isWarning: !over && consumed >= 8_000,
            previousSpentMinor: nil,
            period: DateWindow(start: start, end: TestDates.date(2024, 2, 1, calendar: calendar))
        )
    }
}
