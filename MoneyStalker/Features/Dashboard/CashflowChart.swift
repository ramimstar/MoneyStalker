import Charts
import SwiftUI

struct CashflowChart: View {
    var buckets: [CashflowBucket]
    var currencyCode: String
    var locale: Locale
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            legend
            chart
                .frame(height: 168)
            if let bucket = selectedBucket {
                Text("\(bucket.label) · income \(money(bucket.incomeMinor)) · expenses \(money(bucket.expenseMinor))")
                    .font(.caption)
                    .foregroundStyle(Color.moneyStalkerSlate)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem("Income", total: incomeTotal, tint: .moneyStalkerIncome)
            legendItem("Expenses", total: expenseTotal, tint: .moneyStalkerExpense)
        }
    }

    private func legendItem(_ title: String, total: Int64, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSlate)
                Text(money(total))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.moneyStalkerSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var chart: some View {
        GraphReveal(token: buckets) { reveal in
        Chart {
            ForEach(buckets) { bucket in
                AreaMark(
                    x: .value("Date", bucket.id),
                    y: .value("Amount", ChartMotion.scaled(chartValue(bucket.expenseMinor), reveal))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.moneyStalkerExpense.opacity(0.28), Color.moneyStalkerExpense.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Date", bucket.id),
                    y: .value("Amount", ChartMotion.scaled(chartValue(bucket.incomeMinor), reveal))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.moneyStalkerIncome.opacity(0.32), Color.moneyStalkerIncome.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            ForEach(buckets) { bucket in
                LineMark(
                    x: .value("Date", bucket.id),
                    y: .value("Amount", ChartMotion.scaled(chartValue(bucket.expenseMinor), reveal)),
                    series: .value("Series", "Expenses")
                )
                .foregroundStyle(Color.moneyStalkerExpense)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Date", bucket.id),
                    y: .value("Amount", ChartMotion.scaled(chartValue(bucket.incomeMinor), reveal)),
                    series: .value("Series", "Income")
                )
                .foregroundStyle(Color.moneyStalkerIncome)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            if let selectedBucket {
                RuleMark(x: .value("Date", selectedBucket.id))
                    .foregroundStyle(Color.moneyStalkerSlate.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                PointMark(
                    x: .value("Date", selectedBucket.id),
                    y: .value("Amount", ChartMotion.scaled(chartValue(selectedBucket.incomeMinor), reveal))
                )
                .foregroundStyle(Color.moneyStalkerIncome)
                .symbolSize(70)
                PointMark(
                    x: .value("Date", selectedBucket.id),
                    y: .value("Amount", ChartMotion.scaled(chartValue(selectedBucket.expenseMinor), reveal))
                )
                .foregroundStyle(Color.moneyStalkerExpense)
                .symbolSize(70)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0 ... yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisDate(date))
                            .font(.caption2)
                            .foregroundStyle(Color.moneyStalkerSlate)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
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
        .chartXSelection(value: $selectedDate)
        .chartPlotStyle { plot in
            plot.padding(.trailing, 4)
        }
        }
    }

    private var selectedBucket: CashflowBucket? {
        guard let selectedDate, !buckets.isEmpty else { return nil }
        return buckets.min { abs($0.id.timeIntervalSince(selectedDate)) < abs($1.id.timeIntervalSince(selectedDate)) }
    }

    private var incomeTotal: Int64 { buckets.reduce(0) { $0 + $1.incomeMinor } }
    private var expenseTotal: Int64 { buckets.reduce(0) { $0 + $1.expenseMinor } }

    private var yDomain: Double {
        let peak = buckets.map { max(chartValue($0.incomeMinor), chartValue($0.expenseMinor)) }.max() ?? 0
        return max(peak * 1.18, 1)
    }

    private var accessibilityText: String {
        buckets.map { "\($0.label), income \(money($0.incomeMinor)), expenses \(money($0.expenseMinor))" }
            .joined(separator: ". ")
    }

    private func money(_ minor: Int64) -> String {
        MoneyText.string(minor: minor, code: currencyCode, locale: locale)
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
