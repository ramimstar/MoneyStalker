import Foundation
import SwiftData
import SwiftUI
import UserNotifications

@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let settings: SettingsStore
    let notificationDelegate = NotificationCenterDelegate()
    var isLocked: Bool
    var addTransactionPresented = false
    var tabBarHidden = false
    var selectedTab: AppTab = .home
    var notificationDestination: AppRoute?
    var bootstrapError: String?
    var openedInMemory: Bool

    static let live = AppModel()

    init(inMemory: Bool = false, settings: SettingsStore? = nil) {
        let settings = settings ?? SettingsStore()
        self.settings = settings
        do {
            container = try ModelContainerFactory.make(inMemory: inMemory)
            openedInMemory = inMemory
            bootstrapError = nil
        } catch {
            let fallback = try? ModelContainerFactory.make(inMemory: true)
            if let fallback {
                container = fallback
                openedInMemory = true
                bootstrapError = "Money Stalker could not open saved data. This session will not be stored. \(error.localizedDescription)"
            } else {
                fatalError("Money Stalker could not create a data store.")
            }
        }
        isLocked = settings.appLockEnabled
        UNUserNotificationCenter.current().delegate = notificationDelegate
        notificationDelegate.onOpen = { [weak self] route in
            self?.open(notification: route)
        }
    }

    func open(notification route: String) {
        switch route {
        case "budgets":
            selectedTab = .budgets
        case "activity":
            selectedTab = .transactions
        case "goals":
            selectedTab = .home
            notificationDestination = .goals
        case "debts":
            selectedTab = .home
            notificationDestination = .debts
        case "recurring":
            selectedTab = .home
            notificationDestination = .recurringList
        default:
            selectedTab = .home
        }
    }
}

enum AppTab: Hashable {
    case home, transactions, budgets, settings
}

enum AppRoute: Hashable {
    case transaction(UUID)
    case account(UUID)
    case budget(UUID)
    case goal(UUID)
    case debt(UUID)
    case recurring(UUID)
    case calendar
    case categories
    case accounts
    case goals
    case debts
    case recurringList
    case islamicFinance
    case zakatCalculator
    case zakatTracker
    case zakatEstimate(UUID)
    case financeLibrary
    case libraryArticle(String)
    case ramadanPlanner
    case ramadanPlan(UUID)
}

struct MoneyStalkerDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .transaction(let id): TransactionDetailView(transactionID: id)
            case .account(let id): AccountDetailView(accountID: id)
            case .budget(let id): BudgetDetailView(budgetID: id)
            case .goal(let id): GoalDetailView(goalID: id)
            case .debt(let id): DebtDetailView(debtID: id)
            case .recurring(let id): RecurringEditorView(ruleID: id)
            case .calendar: CalendarView()
            case .categories: CategoriesView()
            case .accounts: AccountsView()
            case .goals: SavingsGoalsView()
            case .debts: DebtsView()
            case .recurringList: RecurringListView()
            case .islamicFinance: IslamicFinanceHubView()
            case .zakatCalculator: ZakatCalculatorView()
            case .zakatTracker: ZakatTrackerView()
            case .zakatEstimate(let id): ZakatEstimateDetailView(calculationID: id)
            case .financeLibrary: FinanceLibraryView()
            case .libraryArticle(let id): FinanceArticleView(articleID: id)
            case .ramadanPlanner: RamadanPlannerView()
            case .ramadanPlan(let id): RamadanPlanDetailView(planID: id)
            }
        }
    }
}

extension View {
    func moneyStalkerDestinations() -> some View { modifier(MoneyStalkerDestinations()) }
}
