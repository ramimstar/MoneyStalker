import SwiftData
import SwiftUI

@MainActor
enum MoneyStalkerPreview {
    static func host<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let model = makeModel()
        return content()
            .environment(model)
            .modelContainer(model.container)
            .tint(Color.moneyStalkerPrimary)
    }

    private static func makeModel() -> AppModel {
        let defaults = UserDefaults(suiteName: "moneyStalker.preview.\(UUID().uuidString)") ?? .standard
        defaults.set(true, forKey: "moneyStalker.onboarding")
        defaults.set("BDT", forKey: "moneyStalker.currency")
        let settings = SettingsStore(defaults: defaults)
        settings.hasCompletedOnboarding = true
        settings.appLockEnabled = false
        settings.currencyCode = "BDT"
        let model = AppModel(inMemory: true, settings: settings)
        model.isLocked = false
        seed(model.container.mainContext)
        return model
    }

    private static func seed(_ context: ModelContext) {
        try? SeedService.seedIfNeeded(context: context)
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let account = Account(name: "Cash", type: .cash, openingBalanceMinor: 10_000_000, currencyCode: "BDT", icon: "banknote", colorHex: "1B7F45")
        context.insert(account)
        let salary = categories.first { $0.name == "Salary" }
        let travel = categories.first { $0.name == "Travel" }
        let entertainment = categories.first { $0.name == "Entertainment" }
        insert(context, account: account, category: salary, type: .income, amount: 10_000_000, notes: "Salary", daysAgo: 6)
        insert(context, account: account, category: travel, type: .expense, amount: 9_000_000, notes: "Travel", daysAgo: 2)
        insert(context, account: account, category: entertainment, type: .expense, amount: 33_300, notes: "Entertainment", daysAgo: 1)
        let budget = Budget(name: "Budget", kind: .monthly, limitMinor: 9_000_000, currencyCode: "BDT", startDate: .now, category: nil)
        context.insert(budget)
        try? context.save()
    }

    private static func insert(_ context: ModelContext, account: Account, category: Category?, type: TransactionType, amount: Int64, notes: String, daysAgo: Int) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let transaction = LedgerTransaction(
            amountMinor: amount,
            destinationAmountMinor: amount,
            type: type,
            currencyCode: "BDT",
            destinationCurrencyCode: "BDT",
            date: date,
            notes: notes
        )
        transaction.account = account
        transaction.category = category
        context.insert(transaction)
    }
}
