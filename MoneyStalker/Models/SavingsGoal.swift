import Foundation
import SwiftData

@Model
final class SavingsGoal {
    var id: UUID
    var name: String
    var targetMinor: Int64
    var currencyCode: String
    var targetDate: Date?
    var icon: String
    var colorHex: String
    var notes: String
    var createdAt: Date
    var linkedAccount: Account?

    @Relationship(deleteRule: .cascade, inverse: \SavingsContribution.goal)
    var contributions: [SavingsContribution] = []

    init(
        id: UUID = UUID(),
        name: String,
        targetMinor: Int64,
        currencyCode: String,
        targetDate: Date? = nil,
        icon: String = "flag",
        colorHex: String = "1877F2",
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.targetMinor = targetMinor
        self.currencyCode = currencyCode
        self.targetDate = targetDate
        self.icon = icon
        self.colorHex = colorHex
        self.notes = notes
        self.createdAt = createdAt
    }

    var snapshot: GoalSnapshot {
        GoalSnapshot(
            id: id,
            name: name,
            targetMinor: targetMinor,
            currencyCode: currencyCode,
            targetDate: targetDate,
            icon: icon,
            colorHex: colorHex
        )
    }
}

@Model
final class SavingsContribution {
    var id: UUID
    var amountMinor: Int64
    var date: Date
    var notes: String
    var createdAt: Date
    var goal: SavingsGoal?
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

    var snapshot: ContributionSnapshot {
        ContributionSnapshot(id: id, goalID: goal?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, amountMinor: amountMinor, date: date)
    }
}
