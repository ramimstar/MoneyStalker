import Foundation

struct AccountSnapshot: Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var type: AccountType
    var openingBalanceMinor: Int64
    var currencyCode: String
    var isArchived: Bool
    var creditLimitMinor: Int64
    var icon: String
    var colorHex: String
    var createdAt: Date
}

struct CategorySnapshot: Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var kind: CategoryKind
    var parentID: UUID?
    var icon: String
    var colorHex: String
    var isArchived: Bool
}

struct TransactionSnapshot: Hashable, Sendable, Identifiable {
    var id: UUID
    var amountMinor: Int64
    var destinationAmountMinor: Int64
    var type: TransactionType
    var linkage: TransactionLinkage
    var principalDirection: PrincipalDirection
    var accountID: UUID
    var counterAccountID: UUID?
    var categoryID: UUID?
    var subcategoryID: UUID?
    var date: Date
    var currencyCode: String
    var destinationCurrencyCode: String
    var notes: String
    var tags: [String]
    var createdAt: Date
    var occurrenceKey: String?

    var effectiveCategoryID: UUID? { subcategoryID ?? categoryID }
}

struct BudgetSnapshot: Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var kind: BudgetPeriodKind
    var limitMinor: Int64
    var currencyCode: String
    var startDate: Date
    var endDate: Date?
    var warningThresholdBasisPoints: Int64
    var rollover: Bool
    var isArchived: Bool
    var categoryID: UUID?
}

struct ContributionSnapshot: Hashable, Sendable, Identifiable {
    var id: UUID
    var goalID: UUID
    var amountMinor: Int64
    var date: Date
}

struct GoalSnapshot: Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var targetMinor: Int64
    var currencyCode: String
    var targetDate: Date?
    var icon: String
    var colorHex: String
}

struct RepaymentSnapshot: Hashable, Sendable, Identifiable {
    var id: UUID
    var debtID: UUID
    var amountMinor: Int64
    var date: Date
}

struct DebtSnapshot: Hashable, Sendable, Identifiable {
    var id: UUID
    var person: String
    var direction: DebtDirection
    var originalMinor: Int64
    var currencyCode: String
    var dueDate: Date?
    var isWrittenOff: Bool
    var interestRateText: String
    var notes: String
}

struct TransactionDraft: Equatable, Sendable {
    var amountMinor: Int64
    var destinationAmountMinor: Int64? = nil
    var type: TransactionType
    var linkage: TransactionLinkage = .none
    var principalDirection: PrincipalDirection = .outbound
    var accountID: UUID? = nil
    var counterAccountID: UUID? = nil
    var categoryID: UUID? = nil
    var subcategoryID: UUID? = nil
    var date: Date
    var notes: String
    var tags: [String]
    var sourceCurrencyCode: String
    var destinationCurrencyCode: String? = nil
    var editingID: UUID? = nil
}

enum TransactionDraftError: LocalizedError, Equatable {
    case invalidAmount
    case amountTooLarge
    case missingAccount
    case archivedAccount
    case missingCategory
    case missingCounterAccount
    case sameAccountTransfer
    case destinationAmountRequired
    case notesTooLong
    case invalidTag
    case likelyDuplicate

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Enter an amount greater than zero."
        case .amountTooLarge: "That amount is too large to store exactly."
        case .missingAccount: "Choose an account."
        case .archivedAccount: "Choose an active account."
        case .missingCategory: "Choose a category."
        case .missingCounterAccount: "Choose the account that receives the transfer."
        case .sameAccountTransfer: "Choose two different accounts."
        case .destinationAmountRequired: "Enter the amount received in the other currency."
        case .notesTooLong: "Notes need to be 2,000 characters or fewer."
        case .invalidTag: "Use up to 12 tags, each 30 characters or fewer."
        case .likelyDuplicate: "A matching transaction was just saved."
        }
    }
}
