import Foundation

enum AccountType: String, Codable, CaseIterable, Identifiable, Sendable {
    case cash, bank, savings, debit, credit, digital, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: "Cash"
        case .bank: "Bank account"
        case .savings: "Savings"
        case .debit: "Debit card"
        case .credit: "Credit card"
        case .digital: "Digital wallet"
        case .custom: "Custom"
        }
    }

    var symbol: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .savings: "leaf"
        case .debit: "creditcard"
        case .credit: "creditcard.fill"
        case .digital: "wallet.pass"
        case .custom: "square.grid.2x2"
        }
    }
}

enum CategoryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense, income
    var id: String { rawValue }
    var title: String { self == .expense ? "Expense" : "Income" }
}

enum TransactionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case income, expense, transfer, principal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .transfer: "Transfer"
        case .principal: "Loan principal"
        }
    }

    var countsAsIncomeOrExpense: Bool {
        self == .income || self == .expense
    }
}

enum TransactionLinkage: String, Codable, Sendable {
    case none
    case debtPrincipal
    case debtRepayment
    case debtInterest
    case goalFunding
}

enum PrincipalDirection: String, Codable, Sendable {
    case inbound, outbound
}

enum BudgetPeriodKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly, monthly, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .custom: "Custom"
        }
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily, weekly, monthly, yearly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

enum DebtDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case borrowed, lent
    var id: String { rawValue }
    var title: String { self == .borrowed ? "I borrowed" : "I lent" }
}

enum DebtDisplayStatus: String, Sendable {
    case active, settled, writtenOff
    var title: String {
        switch self {
        case .active: "Active"
        case .settled: "Settled"
        case .writtenOff: "Written off"
        }
    }
}

enum TransactionSort: String, CaseIterable, Identifiable, Sendable {
    case newest, oldest, highest, lowest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: "Newest"
        case .oldest: "Oldest"
        case .highest: "Highest amount"
        case .lowest: "Lowest amount"
        }
    }
}

enum TransactionGrouping: String, CaseIterable, Identifiable, Sendable {
    case day, month, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .day: "By day"
        case .month: "By month"
        case .none: "No grouping"
        }
    }
}
