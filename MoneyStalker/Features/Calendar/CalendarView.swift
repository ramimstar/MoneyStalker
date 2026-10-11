import SwiftData
import SwiftUI

struct CalendarView: View {
    @Environment(AppModel.self) private var appModel
    @Query private var transactions: [LedgerTransaction]
    @State private var month = Date()
    @State private var selected: Date?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month")
                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next month")
            }
            .padding(.horizontal)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol).font(.caption2.weight(.semibold)).foregroundStyle(Color.moneyStalkerSlate)
                }
                ForEach(cells) { cell in
                    dayCell(cell)
                }
            }
            .padding(.horizontal)
            List {
                if let selected {
                    Section(DateFormatting.string(from: selected, style: appModel.settings.dateStyle, locale: locale, calendar: calendar)) {
                        let dayItems = items(on: selected)
                        if dayItems.isEmpty {
                            Text("No transactions.").foregroundStyle(Color.moneyStalkerSlate)
                        } else {
                            ForEach(dayItems) { transaction in
                                NavigationLink(value: AppRoute.transaction(transaction.id)) {
                                    TransactionRow(transaction: transaction, locale: locale)
                                }
                            }
                        }
                    }
                } else {
                    Text("Select a day.").foregroundStyle(Color.moneyStalkerSlate)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .moneyStalkerScreen()
        .navigationTitle("Calendar")
        .moneyStalkerDestinations()
        .onAppear {
            if selected == nil { selected = calendar.startOfDay(for: .now) }
        }
    }

    private func dayCell(_ cell: MonthCell) -> some View {
        let date = cell.date
        let summary = date.map { daySummary($0) }
        let isSelected = date.map { calendar.isDate($0, inSameDayAs: selected ?? .distantPast) } ?? false
        return Button {
            selected = date
        } label: {
            VStack(spacing: 2) {
                Text(date.map { String(calendar.component(.day, from: $0)) } ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(date == nil ? .clear : Color.moneyStalkerSecondary)
                HStack(spacing: 2) {
                    if (summary?.income ?? 0) > 0 { Circle().fill(Color.moneyStalkerIncome).frame(width: 5, height: 5) }
                    if (summary?.expense ?? 0) > 0 { Circle().fill(Color.moneyStalkerExpense).frame(width: 5, height: 5) }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSelected ? Color.moneyStalkerPrimary.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(date == nil)
        .accessibilityLabel(accessibility(date, summary))
    }

    private func shift(_ value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: month) { month = next }
    }

    private func items(on date: Date) -> [LedgerTransaction] {
        transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }.sorted { $0.date > $1.date }
    }

    private func daySummary(_ date: Date) -> (income: Int64, expense: Int64) {
        let window = DateWindow.covering(startDay: date, endDay: date, calendar: calendar)
        let totals = LedgerCalculator.cashflow(transactions: transactions.map(\.snapshot), window: window, currencyCode: appModel.settings.currencyCode)
        return (totals.incomeMinor, totals.expenseMinor)
    }

    private func accessibility(_ date: Date?, _ summary: (income: Int64, expense: Int64)?) -> String {
        guard let date, let summary else { return "Empty" }
        return "\(calendar.component(.day, from: date)), income \(summary.income), expenses \(summary.expense)"
    }

    private var calendar: Calendar { appModel.settings.calendar }
    private var locale: Locale { appModel.settings.formattingLocale }
    private var cells: [MonthCell] { MonthGridBuilder.cells(for: month, calendar: calendar) }
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month)
    }
}
