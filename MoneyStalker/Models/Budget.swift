import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID
    var name: String
    var periodRaw: String
    var limitMinor: Int64
    var currencyCode: String
    var startDate: Date
    var endDate: Date?
    var warningThreshold: Double
    var rollover: Bool
    var isArchived: Bool
    var createdAt: Date
    var category: Category?

    var kind: BudgetPeriodKind {
        get { BudgetPeriodKind(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: BudgetPeriodKind,
        limitMinor: Int64,
        currencyCode: String,
        startDate: Date,
        endDate: Date? = nil,
        warningThreshold: Double = 0.8,
        rollover: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        category: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.periodRaw = kind.rawValue
        self.limitMinor = limitMinor
        self.currencyCode = currencyCode
        self.startDate = startDate
        self.endDate = endDate
        self.warningThreshold = warningThreshold
        self.rollover = rollover
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.category = category
    }

    var snapshot: BudgetSnapshot {
        BudgetSnapshot(
            id: id,
            name: name,
            kind: kind,
            limitMinor: limitMinor,
            currencyCode: currencyCode,
            startDate: startDate,
            endDate: endDate,
            warningThresholdBasisPoints: Int64((warningThreshold * 10_000).rounded()),
            rollover: rollover,
            isArchived: isArchived,
            categoryID: category?.id
        )
    }
}
