import Foundation
import SwiftData

@MainActor
enum RecurringProcessor {
    @discardableResult
    static func process(context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> Int {
        let rules = try context.fetch(FetchDescriptor<RecurringRule>())
        let transactions = try context.fetch(FetchDescriptor<LedgerTransaction>())
        var existingKeys = Set(transactions.compactMap(\.occurrenceKey))
        var created = 0
        for rule in rules where !rule.isPaused {
            var safety = 0
            while rule.nextOccurrence <= now && safety < 500 {
                safety += 1
                if let end = rule.endDate, rule.nextOccurrence > end { break }
                let key = RecurrenceCalendar.occurrenceKey(ruleID: rule.id, date: rule.nextOccurrence, calendar: calendar)
                let alreadyPosted = rule.processedOccurrenceKeys.contains(key) || existingKeys.contains(key)
                if !alreadyPosted {
                    if !rule.processedOccurrenceKeys.contains(key) {
                        rule.processedOccurrenceKeys.append(key)
                    }
                    if try post(rule: rule, occurrence: rule.nextOccurrence, key: key, context: context) {
                        created += 1
                        existingKeys.insert(key)
                    }
                } else if !rule.processedOccurrenceKeys.contains(key) {
                    rule.processedOccurrenceKeys.append(key)
                }
                guard let next = RecurrenceCalendar.nextDate(after: rule.nextOccurrence, frequency: rule.frequency, interval: rule.interval, calendar: calendar),
                      next > rule.nextOccurrence else { break }
                rule.nextOccurrence = next
            }
            rule.updatedAt = now
        }
        if context.hasChanges {
            try context.save()
        }
        return created
    }

    private static func post(rule: RecurringRule, occurrence: Date, key: String, context: ModelContext) throws -> Bool {
        guard let account = rule.account else {
            rule.isPaused = true
            return false
        }
        if rule.linkage == .debtRepayment, let debtID = rule.linkedDebtID {
            let debts = try context.fetch(FetchDescriptor<Debt>())
            guard let debt = debts.first(where: { $0.id == debtID }) else {
                rule.isPaused = true
                return false
            }
            let outstanding = DebtMath.outstanding(original: debt.originalMinor, repayments: debt.repayments.map(\.amountMinor))
            guard outstanding > 0 else {
                rule.isPaused = true
                return false
            }
            let amount = min(rule.amountMinor, outstanding)
            try DebtWriter.repay(debt: debt, amountMinor: amount, account: account, date: occurrence, notes: rule.notes, context: context, occurrenceKey: key)
            return true
        }

        let destinationAmount = rule.destinationAmountMinor > 0 ? rule.destinationAmountMinor : rule.amountMinor
        let transaction = LedgerTransaction(
            amountMinor: rule.amountMinor,
            destinationAmountMinor: destinationAmount,
            type: rule.type,
            linkage: rule.linkage,
            principalDirection: rule.principalDirection,
            currencyCode: account.currencyCode,
            destinationCurrencyCode: rule.counterAccount?.currencyCode ?? account.currencyCode,
            date: occurrence,
            notes: rule.notes,
            tags: rule.tags,
            occurrenceKey: key,
            linkedDebtID: rule.linkedDebtID,
            linkedGoalID: rule.linkedGoalID
        )
        context.insert(transaction)
        transaction.account = account
        transaction.counterAccount = rule.type == .transfer ? rule.counterAccount : nil
        transaction.category = (rule.type == .income || rule.type == .expense) ? rule.category : nil

        if rule.linkage == .goalFunding, let goalID = rule.linkedGoalID {
            let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
            if let goal = goals.first(where: { $0.id == goalID }), goal.currencyCode == account.currencyCode {
                let contribution = SavingsContribution(amountMinor: rule.amountMinor, date: occurrence, notes: rule.notes)
                context.insert(contribution)
                contribution.goal = goal
                contribution.transaction = transaction
                transaction.linkedContributionID = contribution.id
            }
        }
        return true
    }
}
