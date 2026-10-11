import Foundation

struct SettingsDTO: Codable, Equatable {
    var currencyCode: String
    var weekStart: String
    var dateStyle: String
    var formattingLanguage: String
    var exchangeRates: [String: String]
}

struct BackupFile: Codable, Equatable {
    static let currentVersion = 2
    static let supportedVersions: Set<Int> = [1, 2]

    var formatVersion: Int
    var exportedAt: Date
    var accounts: [AccountDTO]
    var categories: [CategoryDTO]
    var transactions: [TransactionDTO]
    var budgets: [BudgetDTO]
    var recurringRules: [RecurringRuleDTO]
    var goals: [GoalDTO]
    var contributions: [ContributionDTO]
    var debts: [DebtDTO]
    var repayments: [RepaymentDTO]
    var zakatCalculations: [ZakatCalculationDTO]
    var charityRecords: [CharityRecordDTO]
    var charityGoals: [CharityGoalDTO]
    var ramadanPlans: [RamadanPlanDTO]
    var ramadanLinks: [RamadanLinkDTO]
    var libraryBookmarks: [LibraryMarkDTO]
    var libraryVisits: [LibraryMarkDTO]
    var settings: SettingsDTO
}

struct AccountDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var type: String
    var customTypeName: String
    var openingBalanceMinor: Int64
    var currencyCode: String
    var icon: String
    var colorHex: String
    var notes: String
    var isArchived: Bool
    var sortOrder: Int
    var creditLimitMinor: Int64
    var createdAt: Date
    var updatedAt: Date
}

struct CategoryDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var kind: String
    var icon: String
    var colorHex: String
    var isArchived: Bool
    var isSystem: Bool
    var sortOrder: Int
    var parentID: UUID?
}

struct TransactionDTO: Codable, Equatable {
    var id: UUID
    var amountMinor: Int64
    var destinationAmountMinor: Int64
    var type: String
    var linkage: String
    var principalDirection: String
    var currencyCode: String
    var destinationCurrencyCode: String
    var date: Date
    var notes: String
    var tags: [String]
    var occurrenceKey: String?
    var receiptBase64: String?
    var createdAt: Date
    var updatedAt: Date
    var linkedDebtID: UUID?
    var linkedGoalID: UUID?
    var linkedRepaymentID: UUID?
    var linkedContributionID: UUID?
    var accountID: UUID
    var counterAccountID: UUID?
    var categoryID: UUID?
    var subcategoryID: UUID?
}

struct BudgetDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var period: String
    var limitMinor: Int64
    var currencyCode: String
    var startDate: Date
    var endDate: Date?
    var warningThreshold: Double
    var rollover: Bool
    var isArchived: Bool
    var createdAt: Date
    var categoryID: UUID?
}

struct RecurringRuleDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var amountMinor: Int64
    var destinationAmountMinor: Int64
    var type: String
    var linkage: String
    var principalDirection: String
    var currencyCode: String
    var destinationCurrencyCode: String
    var frequency: String
    var interval: Int
    var startDate: Date
    var endDate: Date?
    var nextOccurrence: Date
    var notes: String
    var tags: [String]
    var reminderEnabled: Bool
    var reminderLeadMinutes: Int
    var isPaused: Bool
    var processedOccurrenceKeys: [String]
    var linkedDebtID: UUID?
    var linkedGoalID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var accountID: UUID?
    var counterAccountID: UUID?
    var categoryID: UUID?
}

struct GoalDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var targetMinor: Int64
    var currencyCode: String
    var targetDate: Date?
    var icon: String
    var colorHex: String
    var notes: String
    var createdAt: Date
    var linkedAccountID: UUID?
}

struct ContributionDTO: Codable, Equatable {
    var id: UUID
    var goalID: UUID
    var amountMinor: Int64
    var date: Date
    var notes: String
    var createdAt: Date
    var transactionID: UUID?
}

struct DebtDTO: Codable, Equatable {
    var id: UUID
    var person: String
    var direction: String
    var originalMinor: Int64
    var currencyCode: String
    var dueDate: Date?
    var interestRateText: String
    var notes: String
    var isWrittenOff: Bool
    var reminderEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var accountID: UUID?
}

struct RepaymentDTO: Codable, Equatable {
    var id: UUID
    var debtID: UUID
    var amountMinor: Int64
    var date: Date
    var notes: String
    var createdAt: Date
    var transactionID: UUID?
}

enum BackupError: LocalizedError, Equatable {
    case invalidFile
    case unsupportedVersion(Int)
    case missingAccount(UUID)
    case missingCategory(UUID)
    case missingGoal(UUID)
    case missingDebt(UUID)
    case invalidAmount
    case invalidCurrency

    var errorDescription: String? {
        switch self {
        case .invalidFile: "This file is not a Money Stalker backup."
        case .unsupportedVersion(let version): "Backup version \(version) is not supported."
        case .missingAccount(let id): "The backup refers to a missing account \(id.uuidString)."
        case .missingCategory(let id): "The backup refers to a missing category \(id.uuidString)."
        case .missingGoal(let id): "The backup refers to a missing savings goal \(id.uuidString)."
        case .missingDebt(let id): "The backup refers to a missing debt \(id.uuidString)."
        case .invalidAmount: "The backup contains an invalid amount."
        case .invalidCurrency: "The backup contains an invalid currency code."
        }
    }
}

struct ZakatCalculationDTO: Codable, Equatable {
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
}

struct CharityRecordDTO: Codable, Equatable {
    var id: UUID
    var kindRaw: String
    var amountMinor: Int64
    var currencyCode: String
    var date: Date
    var recipient: String
    var notes: String
    var receiptBase64: String?
    var transactionID: UUID?
    var calculationID: UUID?
    var createdAt: Date
}

struct CharityGoalDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var cadenceRaw: String
    var donationKindRaw: String
    var targetMinor: Int64
    var currencyCode: String
    var startDate: Date
    var endDate: Date?
}

struct RamadanPlanDTO: Codable, Equatable {
    var id: UUID
    var hijriYear: Int
    var startDate: Date
    var endDate: Date
    var currencyCode: String
    var savingsTargetMinor: Int64
    var linesJSON: String
}

struct RamadanLinkDTO: Codable, Equatable {
    var id: UUID
    var planID: UUID
    var lineID: UUID
    var transactionID: UUID
}

struct LibraryMarkDTO: Codable, Equatable {
    var articleID: String
    var date: Date
}

enum BackupCodec {
    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let file = try decoder.decode(BackupFile.self, from: fillIslamicKeys(data))
            try validate(file)
            return file
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.invalidFile
        }
    }

    private static func fillIslamicKeys(_ data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return data }
        let keys = ["zakatCalculations", "charityRecords", "charityGoals", "ramadanPlans", "ramadanLinks", "libraryBookmarks", "libraryVisits"]
        var changed = false
        for key in keys where object[key] == nil {
            object[key] = []
            changed = true
        }
        guard changed else { return data }
        return try JSONSerialization.data(withJSONObject: object)
    }

    static func validate(_ file: BackupFile) throws {
        guard BackupFile.supportedVersions.contains(file.formatVersion) else {
            throw BackupError.unsupportedVersion(file.formatVersion)
        }
        let accountIDs = Set(file.accounts.map(\.id))
        let categoryIDs = Set(file.categories.map(\.id))
        let goalIDs = Set(file.goals.map(\.id))
        let debtIDs = Set(file.debts.map(\.id))
        let transactionIDs = Set(file.transactions.map(\.id))
        for account in file.accounts {
            try requireCurrency(account.currencyCode)
        }
        for category in file.categories {
            if let parent = category.parentID, !categoryIDs.contains(parent) {
                throw BackupError.missingCategory(parent)
            }
        }
        for transaction in file.transactions {
            guard transaction.amountMinor > 0 else { throw BackupError.invalidAmount }
            try requireCurrency(transaction.currencyCode)
            guard accountIDs.contains(transaction.accountID) else { throw BackupError.missingAccount(transaction.accountID) }
            if let counter = transaction.counterAccountID, !accountIDs.contains(counter) {
                throw BackupError.missingAccount(counter)
            }
            if let category = transaction.categoryID, !categoryIDs.contains(category) {
                throw BackupError.missingCategory(category)
            }
            if let subcategory = transaction.subcategoryID, !categoryIDs.contains(subcategory) {
                throw BackupError.missingCategory(subcategory)
            }
        }
        for budget in file.budgets {
            guard budget.limitMinor > 0 else { throw BackupError.invalidAmount }
            if let category = budget.categoryID, !categoryIDs.contains(category) {
                throw BackupError.missingCategory(category)
            }
        }
        for goal in file.goals {
            guard goal.targetMinor > 0 else { throw BackupError.invalidAmount }
            if let account = goal.linkedAccountID, !accountIDs.contains(account) {
                throw BackupError.missingAccount(account)
            }
        }
        for contribution in file.contributions {
            guard contribution.amountMinor > 0 else { throw BackupError.invalidAmount }
            guard goalIDs.contains(contribution.goalID) else { throw BackupError.missingGoal(contribution.goalID) }
            if let transaction = contribution.transactionID, !transactionIDs.contains(transaction) {
                throw BackupError.invalidFile
            }
        }
        for debt in file.debts {
            guard debt.originalMinor > 0 else { throw BackupError.invalidAmount }
            if let account = debt.accountID, !accountIDs.contains(account) {
                throw BackupError.missingAccount(account)
            }
        }
        for repayment in file.repayments {
            guard repayment.amountMinor > 0 else { throw BackupError.invalidAmount }
            guard debtIDs.contains(repayment.debtID) else { throw BackupError.missingDebt(repayment.debtID) }
            if let transaction = repayment.transactionID, !transactionIDs.contains(transaction) {
                throw BackupError.invalidFile
            }
        }
    }

    private static func requireCurrency(_ code: String) throws {
        guard CurrencyCatalog.isKnownISOCode(code) else { throw BackupError.invalidCurrency }
    }
}

enum RestoreGuard {
    static let markerName = "restore-in-progress"
    static let recoveryName = "restore-recovery.json"

    static func begin(data: Data, directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(recoveryName), options: .atomic)
        try Data([1]).write(to: directory.appendingPathComponent(markerName), options: .atomic)
    }

    static func finish(directory: URL) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: directory.appendingPathComponent(markerName))
        try? fileManager.removeItem(at: directory.appendingPathComponent(recoveryName))
    }

    static func needsRecovery(directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(markerName).path)
    }

    static func recoveryData(directory: URL) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(recoveryName))
    }
}
