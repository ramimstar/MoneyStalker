import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var kindRaw: String
    var icon: String
    var colorHex: String
    var isArchived: Bool
    var isSystem: Bool
    var sortOrder: Int

    var parent: Category?

    @Relationship(deleteRule: .nullify, inverse: \Category.parent)
    var children: [Category] = []

    @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.category)
    var transactions: [LedgerTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.subcategory)
    var subcategoryTransactions: [LedgerTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \Budget.category)
    var budgets: [Budget] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.category)
    var recurringRules: [RecurringRule] = []

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: CategoryKind,
        icon: String,
        colorHex: String,
        isArchived: Bool = false,
        isSystem: Bool = false,
        sortOrder: Int = 0,
        parent: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.icon = icon
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.isSystem = isSystem
        self.sortOrder = sortOrder
        self.parent = parent
    }

    var snapshot: CategorySnapshot {
        CategorySnapshot(
            id: id,
            name: name,
            kind: kind,
            parentID: parent?.id,
            icon: icon,
            colorHex: colorHex,
            isArchived: isArchived
        )
    }
}
