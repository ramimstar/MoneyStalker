import Foundation
import SwiftData

struct RamadanLine: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var kind: String
    var plannedMinor: Int64
}

@Model
final class ZakatCalculationRecord {
    var id: UUID
    var createdAt: Date
    var currencyCode: String
    var methodRaw: String
    var hawlConfirmed: Bool
    var hawlDate: Date?
    var cashHomeMinor: Int64
    var bankMinor: Int64
    var investmentsMinor: Int64
    var moneyLentMinor: Int64
    var receivablesMinor: Int64
    var businessCashMinor: Int64
    var inventoryMinor: Int64
    var otherAssetsMinor: Int64
    var includeRetirement: Bool
    var retirementMinor: Int64
    var shortTermLiabilitiesMinor: Int64
    var paidInAdvanceMinor: Int64
    var goldGrams: String
    var goldKarat: String
    var goldPricePerGramMinor: Int64
    var goldPriceSource: String
    var goldPriceDate: Date?
    var silverGrams: String
    var silverFineness: String
    var silverPricePerGramMinor: Int64
    var silverPriceSource: String
    var silverPriceDate: Date?
    var eligibleAssetsMinor: Int64
    var deductionsMinor: Int64
    var netWealthMinor: Int64
    var nisabMinor: Int64
    var nisabKnown: Bool
    var zakatDueMinor: Int64
    var remainingMinor: Int64
    var statusRaw: String
    var notes: [String]
    var engineVersion: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        currencyCode: String,
        methodRaw: String,
        hawlConfirmed: Bool,
        hawlDate: Date?,
        cashHomeMinor: Int64,
        bankMinor: Int64,
        investmentsMinor: Int64,
        moneyLentMinor: Int64,
        receivablesMinor: Int64,
        businessCashMinor: Int64,
        inventoryMinor: Int64,
        otherAssetsMinor: Int64,
        includeRetirement: Bool,
        retirementMinor: Int64,
        shortTermLiabilitiesMinor: Int64,
        paidInAdvanceMinor: Int64,
        goldGrams: String,
        goldKarat: String,
        goldPricePerGramMinor: Int64,
        goldPriceSource: String,
        goldPriceDate: Date?,
        silverGrams: String,
        silverFineness: String,
        silverPricePerGramMinor: Int64,
        silverPriceSource: String,
        silverPriceDate: Date?,
        eligibleAssetsMinor: Int64,
        deductionsMinor: Int64,
        netWealthMinor: Int64,
        nisabMinor: Int64,
        nisabKnown: Bool,
        zakatDueMinor: Int64,
        remainingMinor: Int64,
        statusRaw: String,
        notes: [String],
        engineVersion: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.currencyCode = currencyCode
        self.methodRaw = methodRaw
        self.hawlConfirmed = hawlConfirmed
        self.hawlDate = hawlDate
        self.cashHomeMinor = cashHomeMinor
        self.bankMinor = bankMinor
        self.investmentsMinor = investmentsMinor
        self.moneyLentMinor = moneyLentMinor
        self.receivablesMinor = receivablesMinor
        self.businessCashMinor = businessCashMinor
        self.inventoryMinor = inventoryMinor
        self.otherAssetsMinor = otherAssetsMinor
        self.includeRetirement = includeRetirement
        self.retirementMinor = retirementMinor
        self.shortTermLiabilitiesMinor = shortTermLiabilitiesMinor
        self.paidInAdvanceMinor = paidInAdvanceMinor
        self.goldGrams = goldGrams
        self.goldKarat = goldKarat
        self.goldPricePerGramMinor = goldPricePerGramMinor
        self.goldPriceSource = goldPriceSource
        self.goldPriceDate = goldPriceDate
        self.silverGrams = silverGrams
        self.silverFineness = silverFineness
        self.silverPricePerGramMinor = silverPricePerGramMinor
        self.silverPriceSource = silverPriceSource
        self.silverPriceDate = silverPriceDate
        self.eligibleAssetsMinor = eligibleAssetsMinor
        self.deductionsMinor = deductionsMinor
        self.netWealthMinor = netWealthMinor
        self.nisabMinor = nisabMinor
        self.nisabKnown = nisabKnown
        self.zakatDueMinor = zakatDueMinor
        self.remainingMinor = remainingMinor
        self.statusRaw = statusRaw
        self.notes = notes
        self.engineVersion = engineVersion
    }
}

@Model
final class CharityRecord {
    var id: UUID
    var kindRaw: String
    var amountMinor: Int64
    var currencyCode: String
    var date: Date
    var recipient: String
    var notes: String
    @Attribute(.externalStorage) var receiptImage: Data?
    var transactionID: UUID?
    var calculationID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kindRaw: String,
        amountMinor: Int64,
        currencyCode: String,
        date: Date,
        recipient: String = "",
        notes: String = "",
        receiptImage: Data? = nil,
        transactionID: UUID? = nil,
        calculationID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.date = date
        self.recipient = recipient
        self.notes = notes
        self.receiptImage = receiptImage
        self.transactionID = transactionID
        self.calculationID = calculationID
        self.createdAt = createdAt
    }
}

@Model
final class CharityGoal {
    var id: UUID
    var name: String
    var cadenceRaw: String
    var donationKindRaw: String
    var targetMinor: Int64
    var currencyCode: String
    var startDate: Date
    var endDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        cadenceRaw: String,
        donationKindRaw: String,
        targetMinor: Int64,
        currencyCode: String,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.cadenceRaw = cadenceRaw
        self.donationKindRaw = donationKindRaw
        self.targetMinor = targetMinor
        self.currencyCode = currencyCode
        self.startDate = startDate
        self.endDate = endDate
    }
}

@Model
final class LibraryBookmark {
    var articleID: String
    var savedAt: Date

    init(articleID: String, savedAt: Date = .now) {
        self.articleID = articleID
        self.savedAt = savedAt
    }
}

@Model
final class LibraryVisit {
    var articleID: String
    var viewedAt: Date

    init(articleID: String, viewedAt: Date = .now) {
        self.articleID = articleID
        self.viewedAt = viewedAt
    }
}

@Model
final class RamadanPlan {
    var id: UUID
    var hijriYear: Int
    var startDate: Date
    var endDate: Date
    var currencyCode: String
    var savingsTargetMinor: Int64
    var linesJSON: String

    init(
        id: UUID = UUID(),
        hijriYear: Int,
        startDate: Date,
        endDate: Date,
        currencyCode: String,
        savingsTargetMinor: Int64 = 0,
        lines: [RamadanLine] = RamadanPlan.defaultLines
    ) {
        self.id = id
        self.hijriYear = hijriYear
        self.startDate = startDate
        self.endDate = endDate
        self.currencyCode = currencyCode
        self.savingsTargetMinor = savingsTargetMinor
        self.linesJSON = RamadanPlan.encode(lines)
    }

    func lines() -> [RamadanLine] {
        guard let data = linesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RamadanLine].self, from: data) else { return [] }
        return decoded
    }

    func setLines(_ lines: [RamadanLine]) {
        linesJSON = RamadanPlan.encode(lines)
    }

    static func encode(_ lines: [RamadanLine]) -> String {
        let data = (try? JSONEncoder().encode(lines)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static let defaultLines: [RamadanLine] = [
        RamadanLine(id: UUID(), name: "Iftar groceries", kind: "iftar", plannedMinor: 0),
        RamadanLine(id: UUID(), name: "Suhoor groceries", kind: "suhoor", plannedMinor: 0),
        RamadanLine(id: UUID(), name: "Sadaqah", kind: "charity", plannedMinor: 0),
        RamadanLine(id: UUID(), name: "Zakat set aside", kind: "zakat", plannedMinor: 0),
        RamadanLine(id: UUID(), name: "Eid shopping", kind: "eid", plannedMinor: 0),
        RamadanLine(id: UUID(), name: "Family and guests", kind: "family", plannedMinor: 0)
    ]
}

@Model
final class RamadanLink {
    var id: UUID
    var planID: UUID
    var lineID: UUID
    var transactionID: UUID

    init(id: UUID = UUID(), planID: UUID, lineID: UUID, transactionID: UUID) {
        self.id = id
        self.planID = planID
        self.lineID = lineID
        self.transactionID = transactionID
    }
}
