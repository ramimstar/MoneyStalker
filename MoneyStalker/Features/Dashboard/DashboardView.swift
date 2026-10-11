import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \LedgerTransaction.date, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Budget.createdAt) private var budgets: [Budget]
    @Query(sort: \RecurringRule.nextOccurrence) private var rules: [RecurringRule]
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var contributions: [SavingsContribution]

    @State private var preset: PeriodPreset = .month
    @State private var customStart = Date()
    @State private var customEnd = Date()
    @State private var showCustom = false
    @State private var showNotices = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                content
            }
            .moneyStalkerHidesTabBar(.home)
            .moneyStalkerScreen()
            .toolbar(.hidden, for: .navigationBar)
            .moneyStalkerDestinations()
            .onChange(of: appModel.notificationDestination) { _, route in
                guard let route else { return }
                switch route {
                case .goals, .debts, .recurringList, .calendar, .accounts, .categories, .goal, .debt, .recurring:
                    path.append(route)
                    appModel.notificationDestination = nil
                default:
                    break
                }
            }
            .sheet(isPresented: $showNotices) {
                HomeNoticesSheet(notices: notices)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCustom) {
                NavigationStack {
                    Form { DateRangePicker(start: $customStart, end: $customEnd) }
                        .navigationTitle("Custom range")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showCustom = false } } }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            periodMenu()
            hero
            savingsStrip
            shortcuts
            recent
            chart
            spending
            budgetSection
            accountSection
            upcoming
            goalSection
        }
        .padding(16)
    }

    private func periodMenu(compact: Bool = false) -> some View {
        Menu {
            ForEach(PeriodPreset.allCases) { item in
                Button {
                    if item == .custom { showCustom = true }
                    preset = item
                } label: {
                    if preset == item {
                        Label(item.title, systemImage: "checkmark")
                    } else {
                        Text(item.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(preset.title)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(Color.moneyStalkerSecondary)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 8 : 10)
            .background(compact ? Color.moneyStalkerBackground : Color.moneyStalkerCard)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.moneyStalkerBorder, lineWidth: compact ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.title)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "wallet.pass.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerPrimary)
                .frame(width: 52, height: 52)
                .background(Color.moneyStalkerPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Home")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                Text("Manage your money, build your future")
                    .font(.subheadline)
                    .foregroundStyle(Color.moneyStalkerSlate)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Button { showNotices = true } label: {
                Image(systemName: "bell.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.moneyStalkerCard)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.moneyStalkerBorder, lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        if !notices.isEmpty {
                            Circle()
                                .fill(Color.moneyStalkerExpense)
                                .frame(width: 9, height: 9)
                                .offset(x: 1, y: 1)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(notices.isEmpty ? "Notifications" : "Notifications, \(notices.count) new")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "wallet.pass.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerOnHero)
                    .frame(width: 36, height: 36)
                    .background(heroGlass)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Total balance")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerOnHero.opacity(0.9))
                Spacer()
                Text(preset.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerOnHero)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(heroGlass)
                    .clipShape(Capsule())
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    if let minor = netWorth.displayMinor, let code = netWorth.displayCurrency {
                        Text(MoneyText.string(minor: minor, code: code, locale: locale))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.moneyStalkerOnHero)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    } else {
                        Text("Balances by currency")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.moneyStalkerOnHero)
                        Text(netCaption)
                            .font(.caption)
                            .foregroundStyle(Color.moneyStalkerOnHero.opacity(0.8))
                    }
                    Label(spendingComparison, systemImage: spendingSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(spendingDelta > 0 ? Color(red: 1, green: 0.78, blue: 0.74) : Color.moneyStalkerOnHero)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image("BalanceBag")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 118)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 0) {
                flowStat("In", "arrow.up", flow.incomeMinor, share(flow.incomeMinor), Color.moneyStalkerIncome)
                statDivider
                flowStat("Out", "arrow.up.right", flow.expenseMinor, share(flow.expenseMinor), Color.moneyStalkerExpense)
                statDivider
                flowStat("Net", "minus", flow.netMinor, netShare, Color.moneyStalkerOnHero)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(heroStrip)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background { heroBackground }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
        }
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.moneyStalkerHeroEnd.opacity(0.28), radius: 18, y: 10)
    }

    private var heroGlass: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.14)
    }

    private var heroStrip: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.1)
    }

    private var heroBackground: some View {
        ZStack {
            MoneyStalkerMesh(style: .hero)
            RadialGradient(
                colors: [Color.moneyStalkerPrimary.opacity(colorScheme == .dark ? 0.42 : 0.18), Color.clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 280
            )
        }
    }

    private var savingsStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: "bag.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.moneyStalkerPrimary, Color.moneyStalkerPrimary.opacity(0.16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Savings rate")
                    .font(.caption)
                    .foregroundStyle(Color.moneyStalkerSlate)
                Text(flow.savingsRateBasisPoints.map { MoneyText.percent(basisPoints: $0) } ?? "—")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.moneyStalkerSecondary)
            }
            RangeFill(progress: savingsProgress, tint: Color.moneyStalkerPrimary, height: 6)
        }
        .padding(14)
        .background { MoneyStalkerMesh(style: .card, graph: nil, splash: true) }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func flowStat(_ title: String, _ symbol: String, _ minor: Int64, _ pill: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.moneyStalkerOnHero)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(title == "Net" ? 0.28 : 0.9))
                    .clipShape(Circle())
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerOnHero.opacity(0.85))
            }
            Text(MoneyText.string(minor: minor, code: flow.currencyCode, locale: locale))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.moneyStalkerOnHero)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(pill)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.moneyStalkerOnHero)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.45))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 52)
    }

    private var shortcuts: some View {
        HStack(spacing: 0) {
            shortcut("Accounts", "wallet.pass.fill", .accounts)
            shortcutDivider
            shortcut("Calendar", "calendar", .calendar)
            shortcutDivider
            shortcut("Goals", "flag.fill", .goals)
            shortcutDivider
            shortcut("Debts", "person.2.fill", .debts)
        }
        .padding(.vertical, 6)
        .background { MoneyStalkerMesh(style: .card, graph: .bars) }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
    }

    private var shortcutDivider: some View {
        Rectangle()
            .fill(Color.moneyStalkerBorder)
            .frame(width: 1, height: 36)
    }

    private func shortcut(_ title: String, _ symbol: String, _ route: AppRoute) -> some View {
        NavigationLink(value: route) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.moneyStalkerPrimary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder private var chart: some View {
        if flow.incomeMinor != 0 || flow.expenseMinor != 0 {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.moneyStalkerPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color.moneyStalkerPrimary.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Income and expenses")
                            .font(.headline)
                            .foregroundStyle(Color.moneyStalkerSecondary)
                        Text("Transfers and loan principal are left out.")
                            .font(.caption)
                            .foregroundStyle(Color.moneyStalkerSlate)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    periodMenu(compact: true)
                }
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Label(overviewTitle, systemImage: "chart.bar.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.moneyStalkerSecondary)
                        Spacer()
                        HStack(spacing: 10) {
                            legendDot("Income", Color.moneyStalkerIncome)
                            legendDot("Expenses", Color.moneyStalkerExpense)
                        }
                    }
                    HomeOverviewChart(buckets: overviewBuckets, currencyCode: flow.currencyCode, locale: locale)
                        .frame(height: 188)
                        .padding(.top, 8)
                }
            }
            .padding(16)
            .background { MoneyStalkerMesh(style: .card, graph: nil, splash: true) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
        }
    }

    private func legendDot(_ title: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerSlate)
        }
    }

    @ViewBuilder private var spending: some View {
        if !coloredSpending.isEmpty {
            let shown = Array(coloredSpending.prefix(3))
            let total = coloredSpending.reduce(Int64(0)) { $0 + $1.amountMinor }
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(moneyStalkerHex: "3D6B9A"))
                        .frame(width: 42, height: 42)
                        .background(Color(moneyStalkerHex: "3D6B9A").opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Where it went")
                            .font(.headline)
                            .foregroundStyle(Color.moneyStalkerSecondary)
                        Text("Top expense categories for this period.")
                            .font(.caption)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                    Spacer(minLength: 8)
                    NavigationLink(value: AppRoute.categories) {
                        HStack(spacing: 4) {
                            Text("View details")
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(moneyStalkerHex: "3D6B9A"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(moneyStalkerHex: "3D6B9A").opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 8) {
                        expenseRing
                            .offset(y: -6)
                        VStack(spacing: 2) {
                            Text("Total expenses")
                                .font(.caption2)
                                .foregroundStyle(Color.moneyStalkerSlate)
                            Text(MoneyText.string(minor: total, code: flow.currencyCode, locale: locale))
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.moneyStalkerSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(width: 118)
                    VStack(spacing: 8) {
                        ForEach(shown) { item in
                            NavigationLink(value: AppRoute.categories) {
                                categoryRow(item, total: total)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .background { MoneyStalkerMesh(style: .card, graph: .ring) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
        }
    }

    private var expenseRing: some View {
        GraphReveal(token: coloredSpending) { reveal in
            Chart {
                ForEach(coloredSpending) { item in
                    SectorMark(angle: .value("Share", ChartMotion.scaled(visualShare(of: item), reveal)), innerRadius: .ratio(0.64), angularInset: 1.5)
                        .foregroundStyle(Color(moneyStalkerHex: item.colorHex))
                        .cornerRadius(4)
                }
            }
            .chartLegend(.hidden)
            .frame(width: 118, height: 118)
            .accessibilityLabel("Expense categories")
        }
    }

    private func categoryRow(_ item: CategoryTotal, total: Int64) -> some View {
        let tint = Color(moneyStalkerHex: item.colorHex)
        let share = total > 0 ? (item.amountMinor * 10_000) / total : 0
        return HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.16))
                .clipShape(Circle())
            Text(item.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                Text(MoneyText.string(minor: item.amountMinor, code: item.currencyCode, locale: locale))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.moneyStalkerSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(MoneyText.percent(basisPoints: share))
                    .font(.caption2)
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.moneyStalkerSlate)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private var budgetSection: some View {
        if !budgetStatuses.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Budgets")
                ForEach(Array(budgetStatuses.prefix(3).enumerated()), id: \.element.id) { index, status in
                    NavigationLink(value: AppRoute.budget(status.id)) {
                        let icon = budgetIcon(status.id)
                        BudgetProgressCard(status: status, locale: locale, systemName: icon.symbol, colorHex: icon.hex, graph: CardGraphKind.at(index + 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var accountSection: some View {
        if accounts.contains(where: { !$0.isArchived }) {
            accountRow
        }
    }

    private var accountRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Accounts")
                Spacer()
                NavigationLink("All", value: AppRoute.accounts).font(.subheadline.weight(.semibold))
            }
            ForEach(Array(accounts.filter { !$0.isArchived }.enumerated()), id: \.element.id) { index, account in
                let minor = balance(account)
                let usage = accountUsage(account, balance: minor)
                NavigationLink(value: AppRoute.account(account.id)) {
                    HomeMetricCard(
                        systemName: account.icon,
                        colorHex: account.colorHex,
                        title: account.name,
                        subtitle: usage.subtitle,
                        badge: usage.badge,
                        amount: MoneyText.string(minor: minor, code: account.currencyCode, locale: locale),
                        footer: usage.footer,
                        progress: usage.progress,
                        barColor: usage.barColor,
                        graph: CardGraphKind.at(index)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func budgetIcon(_ id: UUID) -> (symbol: String, hex: String) {
        if let category = budgets.first(where: { $0.id == id })?.category {
            return (category.icon, category.colorHex)
        }
        return ("chart.pie.fill", "1877F2")
    }

    private func accountUsage(_ account: Account, balance: Int64) -> (subtitle: String, badge: String, footer: String, progress: Double, barColor: Color) {
        let typeName = account.type == .custom && !account.customTypeName.isEmpty ? account.customTypeName : account.type.title
        if account.type == .credit, account.creditLimitMinor > 0, balance < 0 {
            let used = (abs(balance) * 10_000) / account.creditLimitMinor
            let remaining = account.creditLimitMinor - abs(balance)
            let footer = remaining >= 0
                ? "Left  •  \(MoneyText.string(minor: remaining, code: account.currencyCode, locale: locale))"
                : "Over limit  •  \(MoneyText.string(minor: abs(remaining), code: account.currencyCode, locale: locale))"
            let subtitle = remaining < 0 ? "Over the limit" : (used >= 8_000 ? "Close to the limit" : "Within the limit")
            let bar: Color = remaining < 0 ? .moneyStalkerExpense : (used >= 8_000 ? .moneyStalkerWarning : Color(moneyStalkerHex: account.colorHex))
            return (subtitle, MoneyText.percent(basisPoints: min(used, 99_999)), footer, min(1, Double(used) / 10_000), bar)
        }
        if balance < 0 {
            return ("Overdrawn", typeName, "Balance is below zero", 1, .moneyStalkerExpense)
        }
        return ("Available", typeName, "Available balance", 1, Color(moneyStalkerHex: account.colorHex))
    }

    @ViewBuilder private var upcoming: some View {
        if !upcomingRules.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle("Coming up")
                    Spacer()
                    NavigationLink("Schedules", value: AppRoute.recurringList).font(.subheadline.weight(.semibold))
                }
                VStack(spacing: 0) {
                    ForEach(Array(upcomingRules.prefix(3).enumerated()), id: \.element.id) { index, rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name.isEmpty ? rule.type.title : rule.name).font(.subheadline.weight(.semibold))
                                Text(DateFormatting.string(from: rule.nextOccurrence, style: appModel.settings.dateStyle, locale: locale, calendar: calendar))
                                    .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                            }
                            Spacer()
                            Text(MoneyText.string(minor: rule.amountMinor, code: rule.currencyCode, locale: locale))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(rule.type == .income ? Color.moneyStalkerIncome : Color.moneyStalkerSecondary)
                        }
                        .padding(.vertical, 10)
                        if index < min(2, upcomingRules.count - 1) { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .background { MoneyStalkerMesh(style: .card, graph: .dots) }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
            }
        }
    }

    @ViewBuilder private var goalSection: some View {
        if !goalProgress.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle("Goals")
                    Spacer()
                    NavigationLink("See all", value: AppRoute.goals).font(.subheadline.weight(.semibold))
                }
                ForEach(Array(goalProgress.prefix(2).enumerated()), id: \.element.id) { index, goal in
                    NavigationLink(value: AppRoute.goal(goal.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                CategoryIcon(systemName: goal.icon, hex: goal.colorHex, size: 32)
                                Text(goal.name).font(.headline)
                                Spacer()
                                Text(MoneyText.percent(basisPoints: min(goal.basisPoints, 10_000)))
                                    .font(.subheadline.weight(.semibold))
                            }
                            RangeFill(progress: min(1, Double(goal.basisPoints) / 10_000), tint: Color.moneyStalkerPrimary)
                            Text("\(MoneyText.string(minor: goal.remainingMinor, code: goal.currencyCode, locale: locale)) remaining")
                                .font(.caption).foregroundStyle(Color.moneyStalkerSlate)
                        }
                        .moneyStalkerCard(graph: index == 0 ? .columns : .wave)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Recent")
                Spacer()
                NavigationLink("Calendar", value: AppRoute.calendar).font(.subheadline.weight(.semibold))
            }
            if transactions.isEmpty {
                Text("Tap Add transaction to record income or an expense.")
                    .font(.subheadline)
                    .foregroundStyle(Color.moneyStalkerSlate)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .moneyStalkerCard(graph: .spark)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(transactions.prefix(5).enumerated()), id: \.element.id) { index, transaction in
                        NavigationLink(value: AppRoute.transaction(transaction.id)) {
                            TransactionRow(transaction: transaction, locale: locale)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if index < min(4, transactions.count - 1) { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .background { MoneyStalkerMesh(style: .card, graph: .spark) }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.title3.weight(.semibold)).foregroundStyle(Color.moneyStalkerSecondary)
    }

    private var locale: Locale { appModel.settings.formattingLocale }
    private var calendar: Calendar { appModel.settings.calendar }
    private var window: DateWindow { PeriodMath.window(preset: preset, customStart: customStart, customEnd: customEnd, now: .now, calendar: calendar) }
    private var snapshots: [TransactionSnapshot] { transactions.map(\.snapshot) }
    private var categorySnapshots: [CategorySnapshot] { categories.map(\.snapshot) }
    private var flow: CashflowTotals {
        LedgerCalculator.cashflow(transactions: snapshots, window: window, currencyCode: appModel.settings.currencyCode)
    }
    private var previousFlow: CashflowTotals {
        LedgerCalculator.cashflow(
            transactions: snapshots,
            window: PeriodMath.previous(of: window, calendar: calendar),
            currencyCode: appModel.settings.currencyCode
        )
    }
    private var spendingDelta: Int64 { flow.expenseMinor - previousFlow.expenseMinor }
    private var spendingSymbol: String {
        if spendingDelta > 0 { return "arrow.up.right" }
        if spendingDelta < 0 { return "arrow.down.right" }
        return "equal"
    }
    private var previousPeriodName: String {
        switch preset {
        case .today: "yesterday"
        case .week: "last week"
        case .month: "last month"
        case .year: "last year"
        case .custom: "the previous period"
        }
    }
    private var spendingComparison: String {
        let amount = MoneyText.string(minor: abs(spendingDelta), code: flow.currencyCode, locale: locale)
        if spendingDelta > 0 { return "Spent \(amount) more than \(previousPeriodName)" }
        if spendingDelta < 0 { return "Spent \(amount) less than \(previousPeriodName)" }
        return "Same spending as \(previousPeriodName)"
    }
    private var notices: [HomeNotice] {
        var items: [HomeNotice] = []
        if spendingDelta != 0 {
            items.append(HomeNotice(
                id: "spend",
                title: spendingDelta > 0 ? "Spending is higher" : "Spending is lower",
                message: spendingComparison,
                symbol: spendingSymbol
            ))
        }
        for status in budgetStatuses where status.isOverBudget || status.isWarning {
            let detail = status.isOverBudget ? "Over the limit" : "Close to the limit"
            let spent = MoneyText.string(minor: status.spentMinor, code: status.currencyCode, locale: locale)
            items.append(HomeNotice(id: status.id.uuidString, title: status.name, message: "\(detail). Spent \(spent).", symbol: status.isOverBudget ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill"))
        }
        for rule in upcomingRules.prefix(5) {
            items.append(HomeNotice(
                id: rule.id.uuidString,
                title: rule.name.isEmpty ? "Scheduled transaction" : rule.name,
                message: "Due \(rule.nextOccurrence.formatted(date: .abbreviated, time: .omitted))",
                symbol: "repeat"
            ))
        }
        return items
    }
    private var savingsProgress: Double {
        guard let rate = flow.savingsRateBasisPoints, rate > 0 else { return 0 }
        return min(Double(rate) / 10_000, 1)
    }
    private var netShare: String {
        guard let rate = flow.savingsRateBasisPoints else { return "—" }
        return MoneyText.percent(basisPoints: rate)
    }
    private func share(_ part: Int64) -> String {
        let base = flow.incomeMinor + flow.expenseMinor
        guard base > 0, part > 0 else { return "0%" }
        return MoneyText.percent(basisPoints: (part * 10_000) / base)
    }
    private func chartValue(_ minor: Int64) -> Double {
        (MoneyMath.major(fromMinor: minor, scale: CurrencyCatalog.fractionDigits(for: flow.currencyCode)) as NSDecimalNumber).doubleValue
    }
    private var overviewTitle: String {
        switch preset {
        case .today: "Today"
        case .week: "This week"
        case .month: "Monthly overview"
        case .year: "Yearly overview"
        case .custom: "Overview"
        }
    }
    private var buckets: [CashflowBucket] {
        LedgerCalculator.buckets(transactions: snapshots, window: window, currencyCode: appModel.settings.currencyCode, accountID: nil, calendar: calendar)
    }
    private var overviewBuckets: [CashflowBucket] {
        if preset == .month { return weekBuckets(in: window) }
        return buckets
    }
    private func weekBuckets(in window: DateWindow) -> [CashflowBucket] {
        var cursor = window.start
        var index = 1
        var results: [CashflowBucket] = []
        while cursor < window.end && index <= 6 {
            guard let step = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            let end = min(step, window.end)
            let totals = LedgerCalculator.cashflow(transactions: snapshots, window: DateWindow(start: cursor, end: end), currencyCode: appModel.settings.currencyCode)
            results.append(CashflowBucket(id: cursor, label: "Week \(index)", incomeMinor: totals.incomeMinor, expenseMinor: totals.expenseMinor))
            cursor = end
            index += 1
        }
        return results
    }
    private var spendingTotals: [CategoryTotal] {
        LedgerCalculator.categoryTotals(transactions: snapshots, categories: categorySnapshots, kind: .expense, window: window, currencyCode: appModel.settings.currencyCode, rollUpToParent: true)
    }
    private var coloredSpending: [CategoryTotal] {
        spendingTotals.map { item in
            CategoryTotal(id: item.id, name: item.name, icon: item.icon, colorHex: expenseColorByName[item.name] ?? item.colorHex, amountMinor: item.amountMinor, currencyCode: item.currencyCode)
        }
    }
    private var expenseColorByName: [String: String] {
        [
            "Food": "D85745",
            "Transport": "3D6B9A",
            "Housing": "8C5A3C",
            "Utilities": "C4841D",
            "Shopping": "6B4C9A",
            "Health": "1B7F45",
            "Education": "2C3E6B",
            "Entertainment": "C43B6E",
            "Travel": "1F8A9E",
            "Family": "E07A3D",
            "Subscriptions": "5C6BC0",
            "Loan Interest": "7A4EAB",
            "Personal Care": "C45B8A",
            "Fitness": "1B8A6B",
            "Clothing": "8E4B8A",
            "Electronics": "3A6EA5",
            "Childcare": "D4894A",
            "Pets": "C47A3A",
            "Insurance": "2C5F8A",
            "Phone": "2F6FED",
            "Internet": "1F8A9E",
            "Gifts Given": "B4536A",
            "Charity": "D4576A",
            "Taxes": "3A4A6B",
            "Fees": "5C6B7A",
            "Repairs": "8C5A3C",
            "Other": "5C6770"
        ]
    }
    private func visualShare(of item: CategoryTotal) -> Double {
        let total = coloredSpending.reduce(0.0) { $0 + max(chartValue($1.amountMinor), 0) }
        let count = Double(coloredSpending.count)
        guard total > 0, count > 0 else { return 1 }
        let share = max(chartValue(item.amountMinor), 0) / total
        let floor = min(0.14, 0.82 / count)
        return floor + share * (1 - floor * count)
    }
    private var netWorth: NetWorthSummary {
        LedgerCalculator.netWorth(accounts: accounts.map(\.snapshot), transactions: snapshots, preferredCurrency: appModel.settings.currencyCode, rates: appModel.settings.parsedRates, includeArchived: true)
    }
    private var budgetStatuses: [BudgetStatus] {
        budgets.filter { !$0.isArchived }.map {
            BudgetEngine.status(budget: $0.snapshot, transactions: snapshots, categories: categorySnapshots, now: .now, calendar: calendar)
        }
    }
    private var upcomingRules: [RecurringRule] {
        let limit = calendar.date(byAdding: .day, value: 30, to: .now) ?? .now
        return rules.filter { !$0.isPaused && $0.nextOccurrence <= limit && $0.nextOccurrence >= calendar.startOfDay(for: .now) }
    }
    private var goalProgress: [GoalProgress] {
        goals.map { GoalMath.progress(goal: $0.snapshot, contributions: contributions.map(\.snapshot)) }
    }
    private var netCaption: String {
        if netWorth.missingRateCurrencies.isEmpty { return "Includes archived accounts. Transfers stay inside this total." }
        return "Missing rates: \(netWorth.missingRateCurrencies.joined(separator: ", "))"
    }
    private func balance(_ account: Account) -> Int64 {
        LedgerCalculator.balanceMinor(for: account.snapshot, transactions: snapshots)
    }
}

#Preview("Home") {
    MoneyStalkerPreview.host { DashboardView() }
}

private struct HomeNotice: Identifiable {
    var id: String
    var title: String
    var message: String
    var symbol: String
}

private struct HomeNoticesSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    var notices: [HomeNotice]
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Allow notifications", isOn: notificationsBinding)
                    Text("Reminders stay on this iPhone. Recurring transactions are created when you open Money Stalker.")
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
                if notices.isEmpty {
                    Section {
                        Text("Nothing new for this period.")
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                } else {
                    Section("Updates") {
                        ForEach(notices) { notice in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: notice.symbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.moneyStalkerPrimary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(notice.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(notice.message)
                                        .font(.caption)
                                        .foregroundStyle(Color.moneyStalkerSlate)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(get: { appModel.settings.notificationsEnabled }, set: { newValue in
            if newValue {
                Task {
                    let granted = await NotificationScheduler.requestAuthorization()
                    appModel.settings.notificationsEnabled = granted
                    if !granted {
                        message = "Notifications stay off until iOS permission is allowed."
                    } else {
                        message = nil
                        await NotificationScheduler.reconcile(context: context, settings: appModel.settings)
                    }
                }
            } else {
                appModel.settings.notificationsEnabled = false
                message = nil
                Task { await NotificationScheduler.reconcile(context: context, settings: appModel.settings) }
            }
        })
    }
}

private struct HomeOverviewChart: View {
    var buckets: [CashflowBucket]
    var currencyCode: String
    var locale: Locale

    var body: some View {
        GraphReveal(token: buckets) { reveal in
        Chart {
            ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                AreaMark(
                    x: .value("Period", index),
                    y: .value("Amount", ChartMotion.scaled(chartValue(bucket.expenseMinor), reveal))
                )
                .foregroundStyle(
                    LinearGradient(colors: [Color.moneyStalkerExpense.opacity(0.28), Color.moneyStalkerExpense.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Period", index),
                    y: .value("Amount", ChartMotion.scaled(chartValue(bucket.incomeMinor), reveal))
                )
                .foregroundStyle(
                    LinearGradient(colors: [Color.moneyStalkerIncome.opacity(0.32), Color.moneyStalkerIncome.opacity(0.03)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Period", index),
                    y: .value("Amount", ChartMotion.scaled(chartValue(bucket.expenseMinor), reveal)),
                    series: .value("Series", "Expenses")
                )
                .foregroundStyle(Color.moneyStalkerExpense)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Period", index),
                    y: .value("Amount", ChartMotion.scaled(chartValue(bucket.incomeMinor), reveal)),
                    series: .value("Series", "Income")
                )
                .foregroundStyle(Color.moneyStalkerIncome)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
            if let last = buckets.indices.last, let bucket = buckets.last {
                PointMark(x: .value("Period", last), y: .value("Amount", ChartMotion.scaled(chartValue(bucket.incomeMinor), reveal)))
                    .foregroundStyle(Color.moneyStalkerIncome)
                    .symbolSize(70)
                PointMark(x: .value("Period", last), y: .value("Amount", ChartMotion.scaled(chartValue(bucket.expenseMinor), reveal)))
                    .foregroundStyle(Color.moneyStalkerExpense)
                    .symbolSize(70)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0 ... yDomain)
        .chartXScale(domain: 0 ... max(buckets.count - 1, 1))
        .chartPlotStyle { plot in
            plot.padding(.top, 18)
        }
        .chartXAxis {
            AxisMarks(values: axisIndexes) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), buckets.indices.contains(index) {
                        Text(buckets[index].label)
                            .font(.caption2)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [3, 4]))
                    .foregroundStyle(Color.moneyStalkerBorder)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.notation(.compactName).locale(locale)))
                            .font(.caption2)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(buckets.map { "\($0.label), income \(money($0.incomeMinor)), expenses \(money($0.expenseMinor))" }.joined(separator: ". "))
        }
    }

    private var axisIndexes: [Int] {
        let count = buckets.count
        guard count > 5 else { return Array(buckets.indices) }
        let step = max(1, count / 3)
        var values = Array(stride(from: 0, to: count, by: step))
        if values.last != count - 1 { values.append(count - 1) }
        return values
    }

    private var yDomain: Double {
        let peak = buckets.map { max(chartValue($0.incomeMinor), chartValue($0.expenseMinor)) }.max() ?? 0
        return max(peak * 1.35, 1)
    }

    private func chartValue(_ minor: Int64) -> Double {
        (MoneyMath.major(fromMinor: minor, scale: CurrencyCatalog.fractionDigits(for: currencyCode)) as NSDecimalNumber).doubleValue
    }

    private func money(_ minor: Int64) -> String {
        MoneyText.string(minor: minor, code: currencyCode, locale: locale)
    }
}

private struct HomeMetricCard: View {
    var systemName: String
    var colorHex: String
    var title: String
    var subtitle: String
    var badge: String
    var amount: String
    var footer: String
    var progress: Double
    var barColor: Color
    var graph: CardGraphKind = .spark

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(moneyStalkerHex: colorHex))
                    .frame(width: 44, height: 44)
                    .background(Color(moneyStalkerHex: colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.moneyStalkerSecondary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(badge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(barColor)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(barColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text(amount)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.moneyStalkerSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            RangeFill(progress: progress, tint: barColor)
            HStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.caption2)
                Text(footer)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.moneyStalkerSlate)
        }
        .padding(18)
        .padding(.leading, 10)
        .background {
            ZStack(alignment: .bottomTrailing) {
                MoneyStalkerMesh(style: .card, graph: graph)
                Circle()
                    .fill(barColor.opacity(0.12))
                    .frame(width: 150, height: 150)
                    .offset(x: 46, y: 36)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.moneyStalkerPrimary)
                .frame(width: 5)
                .padding(.vertical, 18)
                .padding(.leading, 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.moneyStalkerBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}
