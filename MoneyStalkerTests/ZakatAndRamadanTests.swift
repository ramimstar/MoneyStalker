import SwiftData
import XCTest
@testable import MoneyStalker

@MainActor
final class ZakatAndRamadanTests: XCTestCase {
    func testBelowNisabDoesNotCharge() {
        var input = pricedSilverInput()
        input.cashHomeMinor = 100
        let result = ZakatEngine.calculate(input)
        XCTAssertEqual(result.status, .belowNisab)
        XCTAssertEqual(result.zakatDueMinor, 0)
    }

    func testEqualToNisabChargesTwoAndAHalfPercentWhenHawlIsConfirmed() {
        var input = pricedSilverInput()
        let nisab = ZakatEngine.metalValue(grams: ZakatInput.silverNisabGrams, purity: 1, pricePerGramMinor: 1_000)
        input.cashHomeMinor = nisab
        input.hawlConfirmed = true
        let result = ZakatEngine.calculate(input)
        XCTAssertEqual(result.status, .due)
        XCTAssertEqual(result.nisabMinor, nisab)
        XCTAssertEqual(result.zakatDueMinor, ZakatEngine.percent(nisab, numerator: 25, denominator: 1000))
    }

    func testAboveNisabWithoutHawlDoesNotCharge() {
        var input = pricedGoldInput()
        input.bankMinor = 50_000_000
        input.hawlConfirmed = false
        let result = ZakatEngine.calculate(input)
        XCTAssertEqual(result.status, .hawlRequired)
        XCTAssertEqual(result.zakatDueMinor, 0)
        XCTAssertGreaterThan(result.netWealthMinor, result.nisabMinor ?? 0)
    }

    func testMissingSelectedMetalPriceDoesNotInventNisab() {
        var input = ZakatInput()
        input.method = .gold
        input.cashHomeMinor = 9_000_000
        input.hawlConfirmed = true
        let result = ZakatEngine.calculate(input)
        XCTAssertEqual(result.status, .missingPrice)
        XCTAssertNil(result.nisabMinor)
        XCTAssertEqual(result.zakatDueMinor, 0)
    }

    func testShortTermDebtCanBringWealthUnderNisab() {
        var input = pricedSilverInput()
        let nisab = ZakatEngine.metalValue(grams: ZakatInput.silverNisabGrams, purity: 1, pricePerGramMinor: 1_000)
        input.cashHomeMinor = nisab + 500
        input.shortTermLiabilitiesMinor = 600
        input.hawlConfirmed = true
        let result = ZakatEngine.calculate(input)
        XCTAssertEqual(result.status, .belowNisab)
        XCTAssertEqual(result.zakatDueMinor, 0)
    }

    func testPartialAdvancePaymentReducesRemainingOnly() {
        var input = pricedSilverInput()
        let nisab = ZakatEngine.metalValue(grams: ZakatInput.silverNisabGrams, purity: 1, pricePerGramMinor: 2_000)
        input.cashHomeMinor = nisab
        input.hawlConfirmed = true
        let due = ZakatEngine.percent(nisab, numerator: 25, denominator: 1000)
        input.paidInAdvanceMinor = due / 2
        let result = ZakatEngine.calculate(input)
        XCTAssertEqual(result.zakatDueMinor, due)
        XCTAssertEqual(result.eligibleAssetsMinor, nisab)
        XCTAssertEqual(result.remainingMinor, due - due / 2)
    }

    func testOverpaymentDoesNotMakeRemainingNegative() {
        var input = pricedSilverInput()
        input.cashHomeMinor = ZakatEngine.metalValue(grams: ZakatInput.silverNisabGrams, purity: 1, pricePerGramMinor: 1_000)
        input.hawlConfirmed = true
        input.paidInAdvanceMinor = 9_000_000
        XCTAssertEqual(ZakatEngine.calculate(input).remainingMinor, 0)
    }

    func testRetirementStaysOutUntilChosen() {
        var input = pricedGoldInput()
        input.retirementMinor = 8_000_000
        input.includeRetirement = false
        input.hawlConfirmed = true
        let without = ZakatEngine.calculate(input)
        input.includeRetirement = true
        let withRetirement = ZakatEngine.calculate(input)
        XCTAssertEqual(without.retirementIncludedMinor, 0)
        XCTAssertEqual(withRetirement.retirementIncludedMinor, 8_000_000)
    }

    func testTwelveKaratGoldIsHalfThePureValue() {
        let pure = ZakatEngine.metalValue(grams: 10, purity: 1, pricePerGramMinor: 1_000)
        let half = ZakatEngine.metalValue(grams: 10, purity: Decimal(12) / 24, pricePerGramMinor: 1_000)
        XCTAssertEqual(half, pure / 2)
    }

    func testZeroInputsStayAtZero() {
        let result = ZakatEngine.calculate(ZakatInput())
        XCTAssertEqual(result.eligibleAssetsMinor, 0)
        XCTAssertEqual(result.zakatDueMinor, 0)
        XCTAssertEqual(result.status, .missingPrice)
    }

    func testNegativeInputsAreIgnored() {
        var input = pricedSilverInput()
        input.cashHomeMinor = -50
        input.shortTermLiabilitiesMinor = -10
        let result = ZakatEngine.calculate(input)
        XCTAssertEqual(result.eligibleAssetsMinor, 0)
        XCTAssertEqual(result.deductionsMinor, 0)
    }

    func testLaterPaymentsReduceRemainingWithoutChangingTheDueAmount() {
        XCTAssertEqual(CharityMath.remainingAfterPayments(snapshotRemainingMinor: 1_000, laterPaymentsMinor: 400), 600)
        XCTAssertEqual(CharityMath.remainingAfterPayments(snapshotRemainingMinor: 1_000, laterPaymentsMinor: 1_500), 0)
        XCTAssertEqual(CharityMath.remainingAfterPayments(snapshotRemainingMinor: 1_000, laterPaymentsMinor: -20), 1_000)
    }

    func testSameDonationCannotLinkTwice() {
        let id = UUID()
        XCTAssertTrue(CharityMath.canLink(transactionID: id, existingTransactionIDs: []))
        XCTAssertFalse(CharityMath.canLink(transactionID: id, existingTransactionIDs: [id]))
    }

    func testGoalProgressUsesOnlyMatchingCurrencyAndDates() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 5_000)
        let total = CharityMath.progress(
            amounts: [
                (start, 100, "BDT"),
                (Date(timeIntervalSince1970: 2_000), 50, "USD"),
                (Date(timeIntervalSince1970: 9_000), 80, "BDT")
            ],
            currencyCode: "BDT",
            start: start,
            end: end
        )
        XCTAssertEqual(total, 100)
    }

    func testRamadanLinkCountsAnExpenseOnce() {
        let line = UUID()
        let expense = UUID()
        let spent = RamadanMath.spent(
            lineID: line,
            links: [(line, expense), (line, expense), (UUID(), expense)],
            amounts: [expense: 400]
        )
        XCTAssertEqual(spent, 400)
    }

    func testRamadanDateWindowAndWarning() {
        let start = Date(timeIntervalSince1970: 10_000)
        let end = Date(timeIntervalSince1970: 20_000)
        XCTAssertTrue(RamadanMath.contains(start, start: start, end: end))
        XCTAssertTrue(RamadanMath.contains(end, start: start, end: end))
        XCTAssertFalse(RamadanMath.contains(Date(timeIntervalSince1970: 20_001), start: start, end: end))
        XCTAssertTrue(RamadanMath.warns(plannedMinor: 100, actualMinor: 101))
        XCTAssertFalse(RamadanMath.warns(plannedMinor: 0, actualMinor: 50))
    }

    func testBackupRestoresZakatAndDoesNotDuplicate() throws {
        let source = try TestBox()
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        settings.currencyCode = "BDT"
        let record = ZakatCalculationRecord(currencyCode: "BDT", methodRaw: "silver", hawlConfirmed: true, hawlDate: nil, cashHomeMinor: 1_000, bankMinor: 0, investmentsMinor: 0, moneyLentMinor: 0, receivablesMinor: 0, businessCashMinor: 0, inventoryMinor: 0, otherAssetsMinor: 0, includeRetirement: false, retirementMinor: 0, shortTermLiabilitiesMinor: 0, paidInAdvanceMinor: 100, goldGrams: "", goldKarat: "24", goldPricePerGramMinor: 0, goldPriceSource: "", goldPriceDate: nil, silverGrams: "", silverFineness: "0.999", silverPricePerGramMinor: 1_000, silverPriceSource: "Manual", silverPriceDate: .now, eligibleAssetsMinor: 1_000, deductionsMinor: 0, netWealthMinor: 1_000, nisabMinor: 500, nisabKnown: true, zakatDueMinor: 25, remainingMinor: 0, statusRaw: "due", notes: ["snapshot"], engineVersion: 1)
        source.context.insert(record)
        let plan = RamadanPlan(hijriYear: 1447, startDate: .now, endDate: .now, currencyCode: "BDT")
        source.context.insert(plan)
        try source.context.save()
        let data = try BackupService.exportData(context: source.context, settings: settings)
        let destination = try TestBox()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try BackupService.restore(data: data, context: destination.context, settings: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!), directory: directory)
        XCTAssertEqual(try destination.context.fetch(FetchDescriptor<ZakatCalculationRecord>()).count, 1)
        XCTAssertEqual(try destination.context.fetch(FetchDescriptor<RamadanPlan>()).count, 1)
        try BackupService.restore(data: data, context: destination.context, settings: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!), directory: directory)
        XCTAssertEqual(try destination.context.fetch(FetchDescriptor<ZakatCalculationRecord>()).count, 1)
        XCTAssertEqual(try destination.context.fetch(FetchDescriptor<ZakatCalculationRecord>()).first?.zakatDueMinor, 25)
    }

    func testVersionOneBackupStillDecodes() throws {
        let source = try TestBox()
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let data = try BackupService.exportData(context: source.context, settings: settings)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object["formatVersion"] = 1
        for key in ["zakatCalculations", "charityRecords", "charityGoals", "ramadanPlans", "ramadanLinks", "libraryBookmarks", "libraryVisits"] {
            object.removeValue(forKey: key)
        }
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let file = try BackupCodec.decode(legacy)
        XCTAssertEqual(file.formatVersion, 1)
        XCTAssertTrue(file.zakatCalculations.isEmpty)
        XCTAssertTrue(file.ramadanPlans.isEmpty)
    }

    private func pricedSilverInput() -> ZakatInput {
        var input = ZakatInput()
        input.method = .silver
        input.silverPricePerGramMinor = 1_000
        return input
    }

    private func pricedGoldInput() -> ZakatInput {
        var input = ZakatInput()
        input.method = .gold
        input.goldPricePerGramMinor = 5_000
        return input
    }
}
