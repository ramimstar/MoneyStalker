import Charts
import SwiftUI

struct ReportChartStrip: View {
    var buckets: [CashflowBucket]
    var incomeCategories: [CategoryTotal]
    var currencyCode: String
    var locale: Locale

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                areaCard(title: "Income", tint: .moneyStalkerIncome, values: buckets.map(\.incomeMinor))
                areaCard(title: "Expenses", tint: .moneyStalkerExpense, values: buckets.map(\.expenseMinor))
                netCard
                mixCard
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func areaCard(title: String, tint: Color, values: [Int64]) -> some View {
        let total = values.reduce(0, +)
        return card(title: title, amount: total, tint: tint) {
            GraphReveal(token: values) { reveal in
            Chart(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                let value = ChartMotion.scaled(chartValue(index < values.count ? values[index] : 0), reveal)
                AreaMark(x: .value("Date", bucket.id), y: .value(title, value))
                    .foregroundStyle(
                        LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.03)], startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Date", bucket.id), y: .value(title, value))
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            .chartLegend(.hidden)
            .chartYScale(domain: 0 ... domain(values))
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
            }
        }
    }

    private var netCard: some View {
        let nets = buckets.map { $0.incomeMinor - $0.expenseMinor }
        let total = nets.reduce(0, +)
        return card(title: "Net", amount: total, tint: total < 0 ? .moneyStalkerExpense : .moneyStalkerPrimary) {
            GraphReveal(token: nets) { reveal in
            Chart(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                let minor = index < nets.count ? nets[index] : 0
                BarMark(x: .value("Date", bucket.id), y: .value("Net", ChartMotion.scaled(chartValue(minor), reveal)))
                    .foregroundStyle(minor < 0 ? Color.moneyStalkerExpense : Color.moneyStalkerPrimary)
                    .cornerRadius(3)
            }
            .chartLegend(.hidden)
            .chartYScale(domain: netDomain(nets))
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
            }
        }
    }

    private var mixCard: some View {
        card(title: "Income mix", amount: incomeCategories.reduce(0) { $0 + $1.amountMinor }, tint: .moneyStalkerIncome) {
            if incomeCategories.isEmpty {
                Text("No income in this period.")
                    .font(.subheadline)
                    .foregroundStyle(Color.moneyStalkerSlate)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GraphReveal(token: incomeCategories) { reveal in
                Chart(incomeCategories) { item in
                    SectorMark(angle: .value("Amount", ChartMotion.scaled(chartValue(item.amountMinor), reveal)), innerRadius: .ratio(0.62), angularInset: 2)
                        .foregroundStyle(by: .value("Category", item.id.uuidString))
                        .cornerRadius(3)
                }
                .chartForegroundStyleScale(domain: incomeCategories.map(\.id.uuidString), range: incomeCategories.map { Color(moneyStalkerHex: $0.colorHex) })
                .chartLegend(.hidden)
                }
            }
        }
    }

    private func card<Content: View>(title: String, amount: Int64, tint: Color, @ViewBuilder chart: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerSlate)
            Text(MoneyText.string(minor: amount, code: currencyCode, locale: locale))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            chart()
                .frame(height: 132)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background { MoneyStalkerMesh(style: .card, graph: nil).opacity(0.5) }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
        .containerRelativeFrame(.horizontal) { width, _ in width * 0.68 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(MoneyText.string(minor: amount, code: currencyCode, locale: locale))")
    }

    private var dateAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 3)) { value in
            AxisValueLabel {
                if let date = value.as(Date.self) {
                    Text(axisDate(date))
                        .font(.caption2)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
            }
        }
    }

    private var valueAxis: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
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

    private func domain(_ values: [Int64]) -> Double {
        let peak = values.map(chartValue).max() ?? 0
        return max(peak * 1.2, 1)
    }

    private func netDomain(_ values: [Int64]) -> ClosedRange<Double> {
        let numbers = values.map(chartValue)
        let low = min(0, numbers.min() ?? 0)
        let high = max(0, numbers.max() ?? 0)
        if low == 0 && high == 0 { return 0...1 }
        let pad = max((high - low) * 0.18, 1)
        return (low - (low < 0 ? pad : 0)) ... (high + pad)
    }

    private func chartValue(_ minor: Int64) -> Double {
        (MoneyMath.major(fromMinor: minor, scale: CurrencyCatalog.fractionDigits(for: currencyCode)) as NSDecimalNumber).doubleValue
    }

    private func axisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate(buckets.count > 20 ? "d" : "d MMM")
        return formatter.string(from: date)
    }
}
