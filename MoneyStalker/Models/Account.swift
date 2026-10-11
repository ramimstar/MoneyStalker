import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    var name: String
    var typeRaw: String
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

    @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.account)
    var primaryTransactions: [LedgerTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.counterAccount)
    var counterTransactions: [LedgerTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \SavingsGoal.linkedAccount)
    var goals: [SavingsGoal] = []

    @Relationship(deleteRule: .nullify, inverse: \Debt.account)
    var debts: [Debt] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.account)
    var recurringRules: [RecurringRule] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.counterAccount)
    var counterRecurringRules: [RecurringRule] = []

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .cash }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        customTypeName: String = "",
        openingBalanceMinor: Int64,
        currencyCode: String,
        icon: String,
        colorHex: String,
        notes: String = "",
        isArchived: Bool = false,
        sortOrder: Int = 0,
        creditLimitMinor: Int64 = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.customTypeName = customTypeName
        self.openingBalanceMinor = openingBalanceMinor
        self.currencyCode = currencyCode
        self.icon = icon
        self.colorHex = colorHex
        self.notes = notes
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.creditLimitMinor = creditLimitMinor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var snapshot: AccountSnapshot {
        AccountSnapshot(
            id: id,
            name: name,
            type: type,
            openingBalanceMinor: openingBalanceMinor,
            currencyCode: currencyCode,
            isArchived: isArchived,
            creditLimitMinor: creditLimitMinor,
            icon: icon,
            colorHex: colorHex,
            createdAt: createdAt
        )
    }
}
