import Foundation
import SwiftData

@MainActor
enum SeedService {
    struct Item {
        var name: String
        var kind: CategoryKind
        var icon: String
        var color: String
        var children: [(String, String)] = []
    }

    static let defaults: [Item] = [
        .init(name: "Food", kind: .expense, icon: "fork.knife", color: "D85745", children: [("Groceries", "cart"), ("Dining", "fork.knife"), ("Coffee", "cup.and.saucer"), ("Takeout", "takeoutbag.and.cup.and.straw")]),
        .init(name: "Transport", kind: .expense, icon: "car", color: "3D6B9A", children: [("Fuel", "fuelpump"), ("Transit", "bus"), ("Parking", "parkingsign"), ("Rides", "car.side")]),
        .init(name: "Housing", kind: .expense, icon: "house", color: "8C5A3C", children: [("Rent", "house"), ("Maintenance", "wrench.and.screwdriver")]),
        .init(name: "Utilities", kind: .expense, icon: "bolt", color: "C4841D", children: [("Electricity", "bolt"), ("Water", "drop"), ("Gas", "flame")]),
        .init(name: "Shopping", kind: .expense, icon: "bag", color: "6B4C9A"),
        .init(name: "Clothing", kind: .expense, icon: "tshirt", color: "8E4B8A"),
        .init(name: "Electronics", kind: .expense, icon: "desktopcomputer", color: "3A6EA5"),
        .init(name: "Health", kind: .expense, icon: "cross.case", color: "1B7F45", children: [("Pharmacy", "pills"), ("Doctor", "stethoscope")]),
        .init(name: "Fitness", kind: .expense, icon: "figure.run", color: "1B8A6B"),
        .init(name: "Education", kind: .expense, icon: "book", color: "10243A"),
        .init(name: "Travel", kind: .expense, icon: "airplane", color: "1F8A9E"),
        .init(name: "Family", kind: .expense, icon: "figure.2.and.child.holdinghands", color: "E07A3D"),
        .init(name: "Childcare", kind: .expense, icon: "stroller", color: "D4894A"),
        .init(name: "Pets", kind: .expense, icon: "pawprint", color: "C47A3A"),
        .init(name: "Insurance", kind: .expense, icon: "shield", color: "2C5F8A"),
        .init(name: "Phone", kind: .expense, icon: "iphone", color: "2F6FED"),
        .init(name: "Internet", kind: .expense, icon: "wifi", color: "1F8A9E"),
        .init(name: "Gifts Given", kind: .expense, icon: "gift", color: "B4536A"),
        .init(name: "Charity", kind: .expense, icon: "heart", color: "D4576A"),
        .init(name: "Taxes", kind: .expense, icon: "doc.text", color: "3A4A6B"),
        .init(name: "Fees", kind: .expense, icon: "banknote", color: "5C6B7A"),
        .init(name: "Repairs", kind: .expense, icon: "wrench.and.screwdriver", color: "8C5A3C"),
        .init(name: "Loan Interest", kind: .expense, icon: "percent", color: "7A4EAB"),
        .init(name: "Other", kind: .expense, icon: "ellipsis.circle", color: "5C6770"),
        .init(name: "Personal Care", kind: .expense, icon: "sparkles", color: "C45B8A"),
        .init(name: "Entertainment", kind: .expense, icon: "film", color: "C43B6E"),
        .init(name: "Subscriptions", kind: .expense, icon: "repeat", color: "5C6BC0"),
        .init(name: "Salary", kind: .income, icon: "banknote", color: "1B7F45"),
        .init(name: "Bonus", kind: .income, icon: "star", color: "E0A100"),
        .init(name: "Freelance", kind: .income, icon: "laptopcomputer", color: "2F6FED"),
        .init(name: "Business", kind: .income, icon: "briefcase", color: "10243A"),
        .init(name: "Dividends", kind: .income, icon: "chart.pie", color: "1B7F45"),
        .init(name: "Rental", kind: .income, icon: "key", color: "8C5A3C"),
        .init(name: "Gifts", kind: .income, icon: "gift", color: "B4536A"),
        .init(name: "Refund", kind: .income, icon: "arrow.uturn.backward", color: "2F6FED"),
        .init(name: "Sale", kind: .income, icon: "tag", color: "C4841D"),
        .init(name: "Cashback", kind: .income, icon: "creditcard", color: "0E8A7A"),
        .init(name: "Pension", kind: .income, icon: "person", color: "3A6EA5"),
        .init(name: "Allowance", kind: .income, icon: "wallet.pass", color: "6B4C9A"),
        .init(name: "Scholarship", kind: .income, icon: "graduationcap", color: "2C3E6B"),
        .init(name: "Interest Received", kind: .income, icon: "percent", color: "7A4EAB"),
        .init(name: "Other Income", kind: .income, icon: "plus.circle", color: "0E8A7A"),
        .init(name: "Investments", kind: .income, icon: "chart.line.uptrend.xyaxis", color: "C4841D")
    ]

    static func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Category>())
        var parents: [String: Category] = [:]
        for category in existing where category.parent == nil {
            parents[key(category.name, category.kind)] = category
        }
        var childKeys = Set(existing.compactMap { category -> String? in
            guard let parent = category.parent else { return nil }
            return key(parent.name, category.kind) + "|" + category.name.lowercased()
        })
        var nextOrder = (existing.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        var changed = false
        for item in defaults {
            let parentKey = key(item.name, item.kind)
            let parent: Category
            if let found = parents[parentKey] {
                parent = found
            } else {
                parent = Category(name: item.name, kind: item.kind, icon: item.icon, colorHex: item.color, isSystem: true, sortOrder: nextOrder)
                nextOrder += 1
                context.insert(parent)
                parents[parentKey] = parent
                changed = true
            }
            var childOrder = (parent.children.map(\.sortOrder).max() ?? -1) + 1
            for child in item.children {
                let childKey = parentKey + "|" + child.0.lowercased()
                if childKeys.contains(childKey) { continue }
                let subcategory = Category(name: child.0, kind: item.kind, icon: child.1, colorHex: item.color, isSystem: true, sortOrder: childOrder, parent: parent)
                childOrder += 1
                context.insert(subcategory)
                childKeys.insert(childKey)
                changed = true
            }
        }
        let expenseTail = ["Personal Care", "Entertainment", "Subscriptions"]
        let otherExpenses = parents.values.filter { $0.kind == .expense && !expenseTail.contains($0.name) }
        var expenseOrder = (otherExpenses.map(\.sortOrder).max() ?? -1) + 1
        for name in expenseTail {
            guard let category = parents[key(name, .expense)] else { continue }
            if category.sortOrder != expenseOrder {
                category.sortOrder = expenseOrder
                changed = true
            }
            expenseOrder += 1
        }
        if let investments = parents[key("Investments", .income)] {
            let lastIncome = parents.values
                .filter { $0.kind == .income && $0.id != investments.id }
                .map(\.sortOrder)
                .max() ?? -1
            if investments.sortOrder <= lastIncome {
                investments.sortOrder = lastIncome + 1
                changed = true
            }
        }
        if changed { try context.save() }
    }

    private static func key(_ name: String, _ kind: CategoryKind) -> String {
        kind.rawValue + "|" + name.lowercased()
    }
}
