import SwiftUI

struct IslamicFinanceHubView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Estimates stay on this iPhone. They are not a fatwa, and nothing is sent to a charity from here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.moneyStalkerSlate)
                hubLink("Zakat calculator", "Enter assets, a manual metal price, and your hawl choice.", "function", AppRoute.zakatCalculator)
                hubLink("Zakat and sadaqah", "Saved estimates, payments, and charity goals.", "heart.text.square", AppRoute.zakatTracker)
                hubLink("Finance library", "Short articles with their sources named.", "books.vertical", AppRoute.financeLibrary)
                hubLink("Ramadan planner", "Set your own dates and compare a plan with saved expenses.", "moon.stars", AppRoute.ramadanPlanner)
            }
            .padding(16)
        }
        .moneyStalkerScreen()
        .navigationTitle("Islamic Finance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hubLink(_ title: String, _ detail: String, _ symbol: String, _ route: AppRoute) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerIncome)
                    .frame(width: 36, height: 36)
                    .background(Color.moneyStalkerIncome.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.moneyStalkerSecondary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
            .padding(14)
            .moneyStalkerCard()
        }
        .buttonStyle(.plain)
    }
}
