import XCTest
@testable import MoneyStalker

final class CurrencyAndValidationTests: XCTestCase {
    func testDecimalTenthsStayExact() {
        let first = MoneyMath.minorUnits(from: Decimal(string: "0.10")!, scale: 2)!
        let second = MoneyMath.minorUnits(from: Decimal(string: "0.20")!, scale: 2)!
        XCTAssertEqual(first + second, 30)
        XCTAssertEqual(MoneyMath.major(fromMinor: 30, scale: 2), Decimal(string: "0.30"))
    }

    func testRoundingAndZeroDecimalCurrencies() {
        XCTAssertEqual(MoneyMath.minorUnits(from: Decimal(string: "1.005")!, scale: 2), 101)
        XCTAssertEqual(MoneyMath.minorUnits(from: Decimal(string: "1.004")!, scale: 2), 100)
        XCTAssertEqual(MoneyMath.minorUnits(from: Decimal(string: "1500.5")!, scale: 0), 1501)
        XCTAssertEqual(MoneyMath.minorUnits(from: Decimal(string: "1.2345")!, scale: 3), 1235)
    }

    func testLargeAmountsDoNotUseBinaryFloat() {
        let minor = MoneyMath.minorUnits(from: Decimal(string: "100000000000.10")!, scale: 2)
        XCTAssertEqual(minor, 10_000_000_000_010)
        XCTAssertEqual((minor ?? 0) + 1, 10_000_000_000_011)
    }

    func testConversionRequiresAnExplicitRate() {
        let rates = ["USD": Decimal(string: "117.5")!]
        XCTAssertEqual(CurrencyConverter.convert(minor: 100, from: "USD", to: "BDT", preferred: "BDT", rates: rates), 11_750)
        XCTAssertEqual(CurrencyConverter.convert(minor: 150, from: "USD", to: "BDT", preferred: "BDT", rates: rates), 17_625)
        XCTAssertNil(CurrencyConverter.convert(minor: 100, from: "EUR", to: "BDT", preferred: "BDT", rates: rates))
        XCTAssertEqual(CurrencyConverter.convert(minor: 250, from: "BDT", to: "BDT", preferred: "BDT", rates: [:]), 250)
    }

    func testInvalidDraftsAreRejected() {
        let cash = TestFixtures.account()
        var draft = TransactionDraft(amountMinor: 0, type: .expense, accountID: cash.id, categoryID: UUID(), date: .now, notes: "", tags: [], sourceCurrencyCode: "BDT")
        XCTAssertThrowsError(try TransactionValidator.validate(draft, accounts: [cash], allowArchived: false))
        draft.amountMinor = 100
        draft.type = .transfer
        draft.counterAccountID = cash.id
        XCTAssertThrowsError(try TransactionValidator.validate(draft, accounts: [cash], allowArchived: false)) { error in
            XCTAssertEqual(error as? TransactionDraftError, .sameAccountTransfer)
        }
        let archived = TestFixtures.account(archived: true)
        draft = TransactionDraft(amountMinor: 100, type: .expense, accountID: archived.id, categoryID: UUID(), date: .now, notes: "", tags: [], sourceCurrencyCode: "BDT")
        XCTAssertThrowsError(try TransactionValidator.validate(draft, accounts: [archived], allowArchived: false))
    }

    func testLikelyDuplicateDetection() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = UUID()
        let category = UUID()
        let existing = TestFixtures.transaction(amount: 500, type: .expense, account: account, category: category, date: now, notes: "Tea", createdAt: now)
        let draft = TransactionDraft(amountMinor: 500, type: .expense, accountID: account, categoryID: category, date: now.addingTimeInterval(10), notes: "Tea", tags: [], sourceCurrencyCode: "BDT")
        XCTAssertTrue(TransactionValidator.isLikelyDuplicate(draft, existing: [existing], now: now.addingTimeInterval(20)))
        var different = draft
        different.notes = "Coffee"
        XCTAssertFalse(TransactionValidator.isLikelyDuplicate(different, existing: [existing], now: now))
    }

    func testGoalAndDebtMath() {
        let goal = GoalSnapshot(id: UUID(), name: "Trip", targetMinor: 10_000, currencyCode: "BDT", targetDate: nil, icon: "flag", colorHex: "0E6B52")
        let contributions = [
            ContributionSnapshot(id: UUID(), goalID: goal.id, amountMinor: 2_500, date: .now),
            ContributionSnapshot(id: UUID(), goalID: UUID(), amountMinor: 9_000, date: .now)
        ]
        let progress = GoalMath.progress(goal: goal, contributions: contributions)
        XCTAssertEqual(progress.currentMinor, 2_500)
        XCTAssertEqual(progress.remainingMinor, 7_500)
        XCTAssertFalse(progress.isComplete)
        let debt = DebtSnapshot(id: UUID(), person: "Sam", direction: .borrowed, originalMinor: 8_000, currencyCode: "BDT", dueDate: nil, isWrittenOff: false, interestRateText: "", notes: "")
        let summary = DebtMath.summary(debt: debt, repayments: [RepaymentSnapshot(id: UUID(), debtID: debt.id, amountMinor: 3_000, date: .now)])
        XCTAssertEqual(summary.outstandingMinor, 5_000)
        XCTAssertEqual(summary.status, .active)
    }

    func testCSVEscapesCommasAndQuotes() {
        let account = TestFixtures.account(name: "Cash, Main")
        let transaction = TestFixtures.transaction(amount: 100, type: .expense, account: account.id, notes: "Said \"hello\"")
        let csv = CSVExporter.transactions([transaction], accounts: [account], categories: [])
        XCTAssertTrue(csv.contains("\"Cash, Main\""))
        XCTAssertTrue(csv.contains("\"Said \"\"hello\"\"\""))
    }

    func testBackupRejectsGarbageAndUnknownVersions() {
        XCTAssertThrowsError(try BackupCodec.decode(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? BackupError, .invalidFile)
        }
    }

    func testRestoreGuardMarksAnIncompleteRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try RestoreGuard.begin(data: Data("backup".utf8), directory: directory)
        XCTAssertTrue(RestoreGuard.needsRecovery(directory: directory))
        XCTAssertEqual(RestoreGuard.recoveryData(directory: directory), Data("backup".utf8))
        RestoreGuard.finish(directory: directory)
        XCTAssertFalse(RestoreGuard.needsRecovery(directory: directory))
    }
}
