import Foundation
import SwiftData

@Model
final class Debt {
    var id: UUID
    var person: String
    var directionRaw: String
    var originalMinor: Int64
    var currencyCode: String
    var dueDate: Date?
    var interestRateText: String
    var notes: String
    var isWrittenOff: Bool
    var reminderEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var account: Account?

    @Relationship(deleteRule: .cascade, inverse: \DebtRepayment.debt)
    var repayments: [DebtRepayment] = []

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRaw) ?? .borrowed }
        set { directionRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        person: String,
        direction: DebtDirection,
        originalMinor: Int64,
        currencyCode: String,
        dueDate: Date? = nil,
        interestRateText: String = "",
        notes: String = "",
        isWrittenOff: Bool = false,
        reminderEnabled: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.person = person
        self.directionRaw = direction.rawValue
        self.originalMinor = originalMinor
        self.currencyCode = currencyCode
        self.dueDate = dueDate
        self.interestRateText = interestRateText
        self.notes = notes
        self.isWrittenOff = isWrittenOff
        self.reminderEnabled = reminderEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var snapshot: DebtSnapshot {
        DebtSnapshot(
            id: id,
            person: person,
            direction: direction,
            originalMinor: originalMinor,
            currencyCode: currencyCode,
            dueDate: dueDate,
            isWrittenOff: isWrittenOff,
            interestRateText: interestRateText,
            notes: notes
        )
    }
}

@Model
final class DebtRepayment {
    var id: UUID
    var amountMinor: Int64
    var date: Date
    var notes: String
    var createdAt: Date
    var debt: Debt?
    var transaction: LedgerTransaction?

    init(
        id: UUID = UUID(),
        amountMinor: Int64,
        date: Date,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.amountMinor = amountMinor
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
    }

    var snapshot: RepaymentSnapshot {
        RepaymentSnapshot(id: id, debtID: debt?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, amountMinor: amountMinor, date: date)
    }
}
