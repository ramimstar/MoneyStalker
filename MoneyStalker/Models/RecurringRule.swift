import Foundation
import SwiftData

@Model
final class RecurringRule {
    var id: UUID
    var name: String
    var amountMinor: Int64
    var destinationAmountMinor: Int64
    var typeRaw: String
    var linkageRaw: String
    var principalDirectionRaw: String
    var currencyCode: String
    var destinationCurrencyCode: String
    var frequencyRaw: String
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
    var account: Account?
    var counterAccount: Account?
    var category: Category?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var linkage: TransactionLinkage {
        get { TransactionLinkage(rawValue: linkageRaw) ?? .none }
        set { linkageRaw = newValue.rawValue }
    }

    var principalDirection: PrincipalDirection {
        get { PrincipalDirection(rawValue: principalDirectionRaw) ?? .outbound }
        set { principalDirectionRaw = newValue.rawValue }
    }

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        amountMinor: Int64,
        destinationAmountMinor: Int64 = 0,
        type: TransactionType,
        linkage: TransactionLinkage = .none,
        principalDirection: PrincipalDirection = .outbound,
        currencyCode: String,
        destinationCurrencyCode: String,
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        startDate: Date,
        endDate: Date? = nil,
        nextOccurrence: Date,
        notes: String = "",
        tags: [String] = [],
        reminderEnabled: Bool = false,
        reminderLeadMinutes: Int = 60,
        isPaused: Bool = false,
        processedOccurrenceKeys: [String] = [],
        linkedDebtID: UUID? = nil,
        linkedGoalID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.amountMinor = amountMinor
        self.destinationAmountMinor = destinationAmountMinor
        self.typeRaw = type.rawValue
        self.linkageRaw = linkage.rawValue
        self.principalDirectionRaw = principalDirection.rawValue
        self.currencyCode = currencyCode
        self.destinationCurrencyCode = destinationCurrencyCode
        self.frequencyRaw = frequency.rawValue
        self.interval = max(1, interval)
        self.startDate = startDate
        self.endDate = endDate
        self.nextOccurrence = nextOccurrence
        self.notes = notes
        self.tags = tags
        self.reminderEnabled = reminderEnabled
        self.reminderLeadMinutes = reminderLeadMinutes
        self.isPaused = isPaused
        self.processedOccurrenceKeys = processedOccurrenceKeys
        self.linkedDebtID = linkedDebtID
        self.linkedGoalID = linkedGoalID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
