import Foundation
import SwiftData

@Model
final class LedgerTransaction {
    var id: UUID
    var amountMinor: Int64
    var destinationAmountMinor: Int64
    var typeRaw: String
    var linkageRaw: String
    var principalDirectionRaw: String
    var currencyCode: String
    var destinationCurrencyCode: String
    var date: Date
    var notes: String
    var tags: [String]
    var occurrenceKey: String?
    @Attribute(.externalStorage) var receiptImage: Data?
    var createdAt: Date
    var updatedAt: Date
    var linkedDebtID: UUID?
    var linkedGoalID: UUID?
    var linkedRepaymentID: UUID?
    var linkedContributionID: UUID?

    var account: Account?
    var counterAccount: Account?
    var category: Category?
    var subcategory: Category?

    @Relationship(deleteRule: .nullify, inverse: \SavingsContribution.transaction)
    var contributionLinks: [SavingsContribution] = []

    @Relationship(deleteRule: .nullify, inverse: \DebtRepayment.transaction)
    var repaymentLinks: [DebtRepayment] = []

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

    init(
        id: UUID = UUID(),
        amountMinor: Int64,
        destinationAmountMinor: Int64,
        type: TransactionType,
        linkage: TransactionLinkage = .none,
        principalDirection: PrincipalDirection = .outbound,
        currencyCode: String,
        destinationCurrencyCode: String,
        date: Date,
        notes: String = "",
        tags: [String] = [],
        occurrenceKey: String? = nil,
        receiptImage: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        linkedDebtID: UUID? = nil,
        linkedGoalID: UUID? = nil,
        linkedRepaymentID: UUID? = nil,
        linkedContributionID: UUID? = nil
    ) {
        self.id = id
        self.amountMinor = amountMinor
        self.destinationAmountMinor = destinationAmountMinor
        self.typeRaw = type.rawValue
        self.linkageRaw = linkage.rawValue
        self.principalDirectionRaw = principalDirection.rawValue
        self.currencyCode = currencyCode
        self.destinationCurrencyCode = destinationCurrencyCode
        self.date = date
        self.notes = notes
        self.tags = tags
        self.occurrenceKey = occurrenceKey
        self.receiptImage = receiptImage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedDebtID = linkedDebtID
        self.linkedGoalID = linkedGoalID
        self.linkedRepaymentID = linkedRepaymentID
        self.linkedContributionID = linkedContributionID
    }

    var snapshot: TransactionSnapshot {
        TransactionSnapshot(
            id: id,
            amountMinor: amountMinor,
            destinationAmountMinor: destinationAmountMinor,
            type: type,
            linkage: linkage,
            principalDirection: principalDirection,
            accountID: account?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            counterAccountID: counterAccount?.id,
            categoryID: category?.id,
            subcategoryID: subcategory?.id,
            date: date,
            currencyCode: currencyCode,
            destinationCurrencyCode: destinationCurrencyCode,
            notes: notes,
            tags: tags,
            createdAt: createdAt,
            occurrenceKey: occurrenceKey
        )
    }
}
