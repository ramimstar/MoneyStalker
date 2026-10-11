import Charts
import SwiftData
import SwiftUI

struct ReportsView<Controls: View, Overview: View>: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var transactions: [LedgerTransaction]
    @Query private var categories: [Category]
    @Query private var budgets: [Budget]
    @State private var preset: PeriodPreset = .month
    @State private var customStart = Date()
    @State private var customEnd = Date()
    @State private var showCustom = false
    @State private var accountID: UUID?
    var belowControls: Controls
    var aboveOverview: Overview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                periodMenu
                Spacer(minLength: 8)
                accountMenu
            }
            belowControls
            aboveOverview
            overview
            categoryChart(title: "Spending by category", kind: .expense)
            categoryChart(title: "Income by category", kind: .income)
            budgetAndSavings
            netWorthChart
            insights
        }
        .sheet(isPresented: $showCustom) {
            NavigationStack {
                Form { DateRangePicker(start: $customStart, end: $customEnd) }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showCustom = false } } }
                    .navigationTitle("Custom range")
            }
            .presentationDetents([.medium])
        }
    }

    private var periodMenu: some View {
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
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.moneyStalkerSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.moneyStalkerCard)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.moneyStalkerBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var accountMenu: some View {
        Menu {
            Button("All accounts") { accountID = nil }
            ForEach(accounts.filter { !$0.isArchived }) { account in
                Button(account.name) { accountID = account.id }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                Text(accounts.first { $0.id == accountID }?.name ?? "All accounts")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.moneyStalkerSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.moneyStalkerCard)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.moneyStalkerBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wallet.pass.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerPrimary)
                    .frame(width: 46, height: 46)
                    .background(Color.moneyStalkerPrimary.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Income and expenses")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.moneyStalkerSecondary)
                    Text("Transfers and loan principal are left out.")
                        .font(.subheadline)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            ReportChartStrip(buckets: buckets, incomeCategories: incomeCategoryTotals, currencyCode: currency, locale: locale)
                .padding(.bottom, 16)
        }
        .background { MoneyStalkerMesh(style: .card, graph: nil, splash: true) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
    }

    private func categoryChart(title: String, kind: CategoryKind) -> some View {
        let totals = presentedTotals(
            LedgerCalculator.categoryTotals(transactions: snapshots, categories: categorySnapshots, kind: kind, window: window, currencyCode: currency, accountID: accountID, rollUpToParent: true),
            kind: kind
        )
        let tint = kind == .expense ? Color(moneyStalkerHex: "3D6B9A") : Color.moneyStalkerPrimary
        let total = totals.reduce(Int64(0)) { $0 + $1.amountMinor }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kind == .expense ? "clock.fill" : "arrow.down.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.moneyStalkerSecondary)
                    Text("Only \(kind.title.lowercased()) records in \(currency).")
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
            }
            if totals.isEmpty {
                Text("No \(kind.title.lowercased()) records in this period.")
                    .font(.subheadline)
                    .foregroundStyle(Color.moneyStalkerSlate)
                    .padding(.top, 20)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 8) {
                        GraphReveal(token: totals) { reveal in
                            Chart(totals) { item in
                                SectorMark(angle: .value("Share", ChartMotion.scaled(visualShare(of: item, in: totals), reveal)), innerRadius: .ratio(0.64), angularInset: 1.5)
                                    .foregroundStyle(Color(moneyStalkerHex: item.colorHex))
                                    .cornerRadius(4)
                            }
                            .chartLegend(.hidden)
                            .frame(width: 118, height: 118)
                        }
                        .accessibilityLabel(totals.map { "\($0.name) \(MoneyText.string(minor: $0.amountMinor, code: currency, locale: locale))" }.joined(separator: ", "))
                        VStack(spacing: 2) {
                            Text(kind == .expense ? "Total expenses" : "Total income")
                                .font(.caption2)
                                .foregroundStyle(Color.moneyStalkerSlate)
                            Text(MoneyText.string(minor: total, code: currency, locale: locale))
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(kind == .income ? Color.moneyStalkerIncome : Color.moneyStalkerSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(width: 118)
                    VStack(spacing: 8) {
                        ForEach(totals) { item in
                            categoryRow(item, total: total, amountColor: kind == .income ? Color.moneyStalkerIncome : Color.moneyStalkerSecondary)
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
        .homeStyleCard(graph: kind == .expense ? .bars : .ring)
    }

    private func categoryRow(_ item: CategoryTotal, total: Int64, amountColor: Color) -> some View {
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
                Text(MoneyText.string(minor: item.amountMinor, code: currency, locale: locale))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(MoneyText.percent(basisPoints: share))
                    .font(.caption2)
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func presentedTotals(_ totals: [CategoryTotal], kind: CategoryKind) -> [CategoryTotal] {
        let named = kind == .income ? incomeColorByName : expenseColorByName
        let palette = kind == .income
            ? ["1B7F45", "2F6FED", "C4841D", "7A4EAB", "D85745", "0E8A7A", "B4536A", "3A6EA5", "8C5A3C", "5C6BC0"]
            : ["D85745", "2F6FED", "C4841D", "7A4EAB", "1B7F45", "C43B6E", "1F8A9E", "E07A3D", "5C6BC0", "8C5A3C"]
        var used = Set<String>()
        var assigned: [UUID: String] = [:]
        let ordered = totals.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for item in ordered {
            if let hex = named[item.name] {
                assigned[item.id] = hex
                used.insert(hex.uppercased())
            }
        }
        for item in ordered where assigned[item.id] == nil {
            let own = item.colorHex.uppercased()
            if !own.isEmpty && !used.contains(own) {
                assigned[item.id] = item.colorHex
                used.insert(own)
            }
        }
        var index = 0
        for item in ordered where assigned[item.id] == nil {
            var hex = palette[index % palette.count]
            var steps = 0
            while used.contains(hex.uppercased()) && steps < palette.count {
                index += 1
                steps += 1
                hex = palette[index % palette.count]
            }
            index += 1
            used.insert(hex.uppercased())
            assigned[item.id] = hex
        }
        return totals.map { item in
            CategoryTotal(id: item.id, name: item.name, icon: item.icon, colorHex: assigned[item.id] ?? item.colorHex, amountMinor: item.amountMinor, currencyCode: item.currencyCode)
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

    private var incomeColorByName: [String: String] {
        [
            "Salary": "1B7F45",
            "Freelance": "2F6FED",
            "Business": "10243A",
            "Investments": "C4841D",
            "Gifts": "B4536A",
            "Bonus": "E0A100",
            "Refund": "2F6FED",
            "Rental": "8C5A3C",
            "Dividends": "1B7F45",
            "Sale": "C4841D",
            "Cashback": "0E8A7A",
            "Pension": "3A6EA5",
            "Allowance": "6B4C9A",
            "Scholarship": "2C3E6B",
            "Interest Received": "7A4EAB",
            "Other Income": "0E8A7A"
        ]
    }

    private var budgetAndSavings: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Budget")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                if let status = budgetStatuses.first {
                    if status.name.caseInsensitiveCompare("Budget") != .orderedSame {
                        Text(status.name)
                            .font(.caption)
                            .foregroundStyle(Color.moneyStalkerSlate)
                            .lineLimit(1)
                    }
                    Text(MoneyText.percent(basisPoints: status.consumedBasisPoints))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(status.isOverBudget ? Color.moneyStalkerExpense : Color.moneyStalkerPrimary)
                    Text("Spent \(MoneyText.string(minor: status.spentMinor, code: status.currencyCode, locale: locale))")
                        .font(.caption2)
                        .foregroundStyle(Color.moneyStalkerSlate)
                        .lineLimit(2)
                    RangeFill(progress: min(1, Double(status.consumedBasisPoints) / 10_000), tint: status.isOverBudget ? Color.moneyStalkerExpense : Color.moneyStalkerPrimary, height: 6)
                    if budgetStatuses.count > 1 {
                        Text("\(budgetStatuses.count - 1) more")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.moneyStalkerPrimary)
                    }
                } else {
                    Text("No active budgets.")
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Rectangle()
                .fill(Color.moneyStalkerBorder)
                .frame(width: 1)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("Savings rate")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                if let rate = flow.savingsRateBasisPoints {
                    Text(MoneyText.percent(basisPoints: rate))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.moneyStalkerPrimary)
                    Text("Income - Expenses")
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                    RangeFill(progress: rate > 0 ? min(1, Double(rate) / 10_000) : 0, tint: Color.moneyStalkerPrimary, height: 6)
                } else {
                    Text("—")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.moneyStalkerSlate)
                    Text("Needs income in this period.")
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .homeStyleCard(graph: .columns)
    }

    private var netWorthChart: some View {
        let points = sampledNetWorth()
        let latest = points.last
        let change = netWorthChangeBasisPoints(against: latest)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.moneyStalkerPrimary.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Net worth")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.moneyStalkerSecondary)
                    Text("Each point is the calculated balance on that date, including opening balances from accounts that already existed.")
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    netWorthChangePill(change)
                    Text(netWorthComparisonCaption)
                        .font(.caption2)
                        .foregroundStyle(Color.moneyStalkerSlate)
                        .multilineTextAlignment(.trailing)
                }
            }
            if points.isEmpty {
                Text("A single total needs one currency, or exchange rates for every currency you use.")
                    .font(.subheadline)
                    .foregroundStyle(Color.moneyStalkerSlate)
            } else if let latest {
                netWorthPlot(points, latest: latest)
                    .frame(height: 190)
                NavigationLink(value: AppRoute.accounts) {
                    HStack(spacing: 12) {
                        Image(systemName: "banknote.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.moneyStalkerPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.moneyStalkerPrimary.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(netWorthPeriodLabel)
                                .font(.caption)
                                .foregroundStyle(Color.moneyStalkerSlate)
                            Text(MoneyText.string(minor: latest.minor, code: latest.currencyCode, locale: locale))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.moneyStalkerSecondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                    .padding(12)
                    .background(Color.moneyStalkerPrimary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .homeStyleCard(splash: true)
    }

    private func netWorthPlot(_ points: [NetWorthPoint], latest: NetWorthPoint) -> some View {
        let values = points.map { chartValue($0.minor) }
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let domain = netWorthDomain(low: low, high: high)
        return GraphReveal(token: points) { reveal in
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Base", 0),
                yEnd: .value("Balance", ChartMotion.scaled(chartValue(point.minor), reveal))
            )
            .foregroundStyle(LinearGradient(colors: [Color.moneyStalkerPrimary.opacity(0.28), Color.moneyStalkerPrimary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
            LineMark(x: .value("Date", point.date), y: .value("Balance", ChartMotion.scaled(chartValue(point.minor), reveal)))
                .foregroundStyle(Color.moneyStalkerPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            if point.id == latest.id {
                PointMark(x: .value("Date", point.date), y: .value("Balance", ChartMotion.scaled(chartValue(point.minor), reveal)))
                    .symbol {
                        ZStack {
                            Circle().fill(Color.moneyStalkerCard)
                            Circle().stroke(Color.moneyStalkerPrimary, lineWidth: 2.5)
                        }
                        .frame(width: 12, height: 12)
                    }
                    .annotation(position: .top, spacing: 6) {
                        Text(MoneyText.string(minor: point.minor, code: point.currencyCode, locale: locale))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.moneyStalkerOnHero)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.moneyStalkerPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisDay(date))
                            .font(.caption2)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.moneyStalkerBorder.opacity(0.8))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.grouping(.automatic).precision(.fractionLength(0)).locale(locale)))
                            .font(.caption2)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
            }
        }
        .accessibilityLabel(points.map { "\(axisDay($0.date)) \(MoneyText.string(minor: $0.minor, code: $0.currencyCode, locale: locale))" }.joined(separator: ", "))
        }
    }

    private var insights: some View {
        let previousWindow = PeriodMath.previous(of: window, calendar: calendar)
        let previous = LedgerCalculator.cashflow(transactions: snapshots, window: previousWindow, currencyCode: currency, accountID: accountID)
        let spending = LedgerCalculator.categoryTotals(transactions: snapshots, categories: categorySnapshots, kind: .expense, window: window, currencyCode: currency, accountID: accountID, rollUpToParent: true)
        let items = InsightsEngine.make(current: flow, previous: previous, spending: spending, budgets: budgetStatuses)
        return VStack(alignment: .leading, spacing: 12) {
            Text("From your records")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.moneyStalkerSecondary)
            Text("Comparisons use saved transactions only.")
                .font(.caption)
                .foregroundStyle(Color.moneyStalkerSlate)
            if items.isEmpty {
                Text("Nothing to compare in this period.")
                    .font(.subheadline)
                    .foregroundStyle(Color.moneyStalkerSlate)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        insightRow(item)
                    }
                }
            }
        }
        .homeStyleCard(graph: .dots)
    }

    @ViewBuilder
    private func insightRow(_ item: Insight) -> some View {
        switch item.id {
        case "top":
            NavigationLink(value: AppRoute.categories) { insightRowBody(item) }
                .buttonStyle(.plain)
        case "over":
            Button { appModel.selectedTab = .budgets } label: { insightRowBody(item) }
                .buttonStyle(.plain)
        default:
            insightRowBody(item)
        }
    }

    private func insightRowBody(_ item: Insight) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerPrimary)
                .frame(width: 40, height: 40)
                .background(Color.moneyStalkerPrimary.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                Text(item.message)
                    .font(.caption)
                    .foregroundStyle(Color.moneyStalkerSlate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(item.badge)
                .font(.caption.weight(.semibold))
                .foregroundStyle(insightToneColor(item.tone))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(insightToneColor(item.tone).opacity(0.14))
                .clipShape(Capsule())
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.moneyStalkerSlate)
        }
        .padding(12)
        .background(Color.moneyStalkerPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func insightToneColor(_ tone: InsightTone) -> Color {
        switch tone {
        case .neutral: Color.moneyStalkerSlate
        case .accent: Color.moneyStalkerPrimary
        case .positive: Color.moneyStalkerIncome
        case .negative: Color.moneyStalkerExpense
        }
    }

    private var netWorthPeriodLabel: String {
        switch preset {
        case .today: "Net worth today"
        case .week: "Net worth this week"
        case .month: "Net worth this month"
        case .year: "Net worth this year"
        case .custom: "Net worth in this range"
        }
    }

    private var netWorthComparisonCaption: String {
        switch preset {
        case .today: "vs yesterday"
        case .week: "vs last week"
        case .month: "vs last month"
        case .year: "vs last year"
        case .custom: "vs previous period"
        }
    }

    private func netWorthChangePill(_ basisPoints: Int64?) -> some View {
        let tint: Color = {
            guard let basisPoints else { return Color.moneyStalkerSlate }
            if basisPoints > 0 { return Color.moneyStalkerPrimary }
            if basisPoints < 0 { return Color.moneyStalkerExpense }
            return Color.moneyStalkerSlate
        }()
        return HStack(spacing: 3) {
            if let basisPoints, basisPoints != 0 {
                Image(systemName: basisPoints > 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2.weight(.bold))
            }
            Text(basisPoints.map { signedPercent($0) } ?? "—")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private func signedPercent(_ basisPoints: Int64) -> String {
        let text = MoneyText.percent(basisPoints: abs(basisPoints))
        if basisPoints > 0 { return "+\(text)" }
        if basisPoints < 0 { return "−\(text)" }
        return text
    }

    /// Change from the balance just before this period to the latest point. Nil when the earlier balance is missing or zero.
    private func netWorthChangeBasisPoints(against latest: NetWorthPoint?) -> Int64? {
        guard let latest else { return nil }
        let active = accounts.map(\.snapshot).filter { !$0.isArchived }
        let earlier = LedgerCalculator.netWorth(
            accounts: active,
            transactions: snapshots,
            preferredCurrency: currency,
            rates: appModel.settings.parsedRates,
            includeArchived: false,
            asOf: window.start.addingTimeInterval(-1)
        )
        guard earlier.displayCurrency == latest.currencyCode, let previous = earlier.displayMinor, previous != 0 else { return nil }
        return ((latest.minor - previous) * 10_000) / abs(previous)
    }

    private func sampledNetWorth() -> [NetWorthPoint] {
        let active = accounts.map(\.snapshot).filter { !$0.isArchived }
        guard !active.isEmpty else { return [] }
        let rates = appModel.settings.parsedRates
        let probe = LedgerCalculator.netWorth(accounts: active, transactions: snapshots, preferredCurrency: currency, rates: rates, includeArchived: false)
        guard probe.displayCurrency != nil else { return [] }

        let horizon = min(window.end.addingTimeInterval(-1), Date())
        guard horizon >= window.start else { return [] }
        let span = calendar.dateComponents([.day], from: window.start, to: horizon).day ?? 0
        let stepDays = span <= 35 ? 1 : (span <= 140 ? 7 : 30)

        var points: [NetWorthPoint] = []
        var cursor = window.start
        var safety = 0
        while cursor <= horizon && safety < 48 {
            safety += 1
            if let point = netWorthPoint(on: cursor, accounts: active, rates: rates) {
                points.append(point)
            }
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: cursor) else { break }
            cursor = next
        }
        if points.last.map({ calendar.isDate($0.date, inSameDayAs: horizon) }) != true,
           let point = netWorthPoint(on: horizon, accounts: active, rates: rates) {
            points.append(point)
        }
        return points
    }

    private func netWorthPoint(on date: Date, accounts: [AccountSnapshot], rates: [String: Decimal]) -> NetWorthPoint? {
        let summary = LedgerCalculator.netWorth(accounts: accounts, transactions: snapshots, preferredCurrency: currency, rates: rates, includeArchived: false, asOf: date)
        guard let minor = summary.displayMinor, let code = summary.displayCurrency else { return nil }
        return NetWorthPoint(id: date, date: date, minor: minor, currencyCode: code)
    }

    private func netWorthDomain(low: Double, high: Double) -> ClosedRange<Double> {
        if low >= 0 {
            return 0...max(high * 1.28, 1)
        }
        let pad = max((high - low) * 0.18, 1)
        return (low - pad)...(high + pad * 1.4)
    }

    private func axisDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private var locale: Locale { appModel.settings.formattingLocale }
    private var calendar: Calendar { appModel.settings.calendar }
    private var currency: String { appModel.settings.currencyCode }
    private var window: DateWindow { PeriodMath.window(preset: preset, customStart: customStart, customEnd: customEnd, now: .now, calendar: calendar) }
    private var snapshots: [TransactionSnapshot] { transactions.map(\.snapshot) }
    private var categorySnapshots: [CategorySnapshot] { categories.map(\.snapshot) }
    private var flow: CashflowTotals { LedgerCalculator.cashflow(transactions: snapshots, window: window, currencyCode: currency, accountID: accountID) }
    private var buckets: [CashflowBucket] { LedgerCalculator.buckets(transactions: snapshots, window: window, currencyCode: currency, accountID: accountID, calendar: calendar) }
    private var incomeCategoryTotals: [CategoryTotal] {
        presentedTotals(
            LedgerCalculator.categoryTotals(transactions: snapshots, categories: categorySnapshots, kind: .income, window: window, currencyCode: currency, accountID: accountID, rollUpToParent: true),
            kind: .income
        )
    }
    private var budgetStatuses: [BudgetStatus] {
        budgets.filter { !$0.isArchived && (accountID == nil) }.map {
            BudgetEngine.status(budget: $0.snapshot, transactions: snapshots, categories: categorySnapshots, now: .now, calendar: calendar)
        }
    }
    private func visualShare(of item: CategoryTotal, in totals: [CategoryTotal]) -> Double {
        let total = totals.reduce(0.0) { $0 + max(chartValue($1.amountMinor), 0) }
        let count = Double(totals.count)
        guard total > 0, count > 0 else { return 1 }
        let share = max(chartValue(item.amountMinor), 0) / total
        let floor = min(0.14, 0.82 / count)
        return floor + share * (1 - floor * count)
    }

    private func chartValue(_ minor: Int64) -> Double {
        (MoneyMath.major(fromMinor: minor, scale: CurrencyCatalog.fractionDigits(for: currency)) as NSDecimalNumber).doubleValue
    }
}

private extension View {
    func homeStyleCard(graph: CardGraphKind? = .line, splash: Bool = false) -> some View {
        padding(16)
            .background { MoneyStalkerMesh(style: .card, graph: splash ? nil : graph, splash: splash) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
    }
}

extension ReportsView where Controls == EmptyView, Overview == EmptyView {
    init() {
        self.init(belowControls: EmptyView(), aboveOverview: EmptyView())
    }
}

#Preview("Reports") {
    MoneyStalkerPreview.host {
        NavigationStack {
            ScrollView { ReportsView().padding(16) }
                .moneyStalkerScreen()
        }
    }
}
