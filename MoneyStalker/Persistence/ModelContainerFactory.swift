import Foundation
import SwiftData

enum ModelContainerFactory {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Account.self,
            Category.self,
            LedgerTransaction.self,
            Budget.self,
            RecurringRule.self,
            SavingsGoal.self,
            SavingsContribution.self,
            Debt.self,
            DebtRepayment.self,
            ZakatCalculationRecord.self,
            CharityRecord.self,
            CharityGoal.self,
            LibraryBookmark.self,
            LibraryVisit.self,
            RamadanPlan.self,
            RamadanLink.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
