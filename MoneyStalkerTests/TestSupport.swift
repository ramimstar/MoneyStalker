import Foundation
import XCTest
@testable import MoneyStalker

enum TestDates {
    static func calendar(firstWeekday: Int = 1) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, calendar: Calendar? = nil) -> Date {
        let calendar = calendar ?? self.calendar()
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: 0))!
    }
}

enum TestFixtures {
    static func account(
        id: UUID = UUID(),
        name: String = "Cash",
        type: AccountType = .cash,
        opening: Int64 = 0,
        currency: String = "BDT",
        archived: Bool = false,
        createdAt: Date = .distantPast
    ) -> AccountSnapshot {
        AccountSnapshot(id: id, name: name, type: type, openingBalanceMinor: opening, currencyCode: currency, isArchived: archived, creditLimitMinor: 0, icon: "banknote", colorHex: "0E6B52", createdAt: createdAt)
    }

    static func transaction(
        amount: Int64,
        type: TransactionType,
        account: UUID,
        counter: UUID? = nil,
        destination: Int64? = nil,
        category: UUID? = nil,
        subcategory: UUID? = nil,
        date: Date = Date(timeIntervalSince1970: 1_700_000_000),
        currency: String = "BDT",
        destinationCurrency: String? = nil,
        linkage: TransactionLinkage = .none,
        direction: PrincipalDirection = .outbound,
        notes: String = "",
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> TransactionSnapshot {
        TransactionSnapshot(
            id: UUID(),
            amountMinor: amount,
            destinationAmountMinor: destination ?? amount,
            type: type,
            linkage: linkage,
            principalDirection: direction,
            accountID: account,
            counterAccountID: counter,
            categoryID: category,
            subcategoryID: subcategory,
            date: date,
            currencyCode: currency,
            destinationCurrencyCode: destinationCurrency ?? currency,
            notes: notes,
            tags: [],
            createdAt: createdAt,
            occurrenceKey: nil
        )
    }

    static func category(id: UUID = UUID(), name: String, kind: CategoryKind = .expense, parent: UUID? = nil) -> CategorySnapshot {
        CategorySnapshot(id: id, name: name, kind: kind, parentID: parent, icon: "tag", colorHex: "0E6B52", isArchived: false)
    }
}
