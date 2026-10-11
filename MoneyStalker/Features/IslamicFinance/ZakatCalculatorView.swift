import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct ZakatCalculatorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @State private var method: ZakatNisabMethod = .silver
    @State private var hawlConfirmed = false
    @State private var hawlDate = Date()
    @State private var hasHawlDate = false
    @State private var cash = ""
    @State private var bank = ""
    @State private var investments = ""
    @State private var lent = ""
    @State private var receivables = ""
    @State private var businessCash = ""
    @State private var inventory = ""
    @State private var other = ""
    @State private var includeRetirement = false
    @State private var retirement = ""
    @State private var liabilities = ""
    @State private var paid = ""
    @State private var goldGrams = ""
    @State private var goldKarat = "24"
    @State private var goldPrice = ""
    @State private var goldSource = ""
    @State private var goldDate = Date()
    @State private var silverGrams = ""
    @State private var silverFineness = "0.999"
    @State private var silverPrice = ""
    @State private var silverSource = ""
    @State private var silverDate = Date()
    @State private var result: ZakatResult?
    @State private var message: String?
    @State private var padFocused = false

    var body: some View {
        Form {
            Section {
                Text("This is a personal estimate using the charity method described in the library. It is not a binding ruling, and it does not use Saudi business zakat rules.")
                    .font(.footnote)
                    .foregroundStyle(Color.moneyStalkerSlate)
                Picker("Nisab", selection: $method) {
                    ForEach(ZakatNisabMethod.allCases) { Text($0.title).tag($0) }
                }
                Text(method == .gold ? "Gold nisab uses 87.48 grams. Enter your own price per gram." : "Silver nisab uses 612.36 grams. Enter your own price per gram.")
                    .font(.footnote)
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
            Section {
                Toggle("Hawl condition is met", isOn: $hawlConfirmed)
                Toggle("Record a hawl date", isOn: $hasHawlDate)
                if hasHawlDate { DatePicker("Hawl date", selection: $hawlDate, displayedComponents: .date) }
            } footer: {
                Text("The amount is estimated as due only after you confirm hawl. A saved date can remind you about 354 days later. That count is an approximation, not a moon-sighting date.")
            }
            Section("Cash") {
                moneyField("Cash at home", "Money you hold that you are including.", $cash)
                moneyField("Checking and savings", "Balances still in your accounts.", $bank)
            }
            Section {
                decimalField("Weight in grams", $goldGrams)
                decimalField("Karat (24 is pure)", $goldKarat)
                moneyField("Price per gram", "Manual price. Not a live quote.", $goldPrice)
                TextField("Price source", text: $goldSource)
                DatePicker("Price date", selection: $goldDate, displayedComponents: .date)
            } header: {
                Text("Gold")
            } footer: {
                Text("Jewelry is not added for you. Schools differ. Include it in the weight only if you are following a view that counts it. Karat is converted toward pure gold.")
            }
            Section("Silver") {
                decimalField("Weight in grams", $silverGrams)
                decimalField("Fineness from 0 to 1", $silverFineness)
                moneyField("Price per gram", "Manual price. Not a live quote.", $silverPrice)
                TextField("Price source", text: $silverSource)
                DatePicker("Price date", selection: $silverDate, displayedComponents: .date)
            }
            Section {
                moneyField("Investments and shares", "Enter only the value you have decided is eligible.", $investments)
                moneyField("Money lent to others", "Loans you expect to be repaid.", $lent)
                moneyField("Receivables", "Do not include unpaid wages unless you have decided they are already due.", $receivables)
                moneyField("Business cash", "Cash that belongs to trade.", $businessCash)
                moneyField("Trade inventory", "Goods bought to sell. Not tools you need to keep working.", $inventory)
                moneyField("Other assets you are including", "Anything else this method should count.", $other)
                Toggle("Include retirement savings", isOn: $includeRetirement)
                if includeRetirement {
                    moneyField("Retirement amount", "Only the portion you chose to include.", $retirement)
                }
            } header: {
                Text("Other eligible amounts")
            } footer: {
                Text("Islamic Relief and Zakat Foundation do not describe pensions the same way. The switch stays off until you choose.")
            }
            Section("Deductions") {
                moneyField("Short-term liabilities", "Bills or the current installment you are deducting. Do not enter a whole mortgage unless that is your chosen method.", $liabilities)
                moneyField("Zakat already paid", "This lowers the remaining amount. It does not change the wealth total.", $paid)
            }
            if let result {
                Section("Estimate") {
                    line("Eligible assets", result.eligibleAssetsMinor)
                    line("Short-term deductions", result.deductionsMinor)
                    line("Net eligible wealth", result.netWealthMinor)
                    if let nisab = result.nisabMinor {
                        line("Selected nisab", nisab)
                    } else {
                        LabeledContent("Selected nisab", value: "Needs a manual price")
                    }
                    line("Estimated zakat", result.zakatDueMinor)
                    line("Already paid", minor(paid))
                    line("Remaining", result.remainingMinor)
                    Text(statusText(result))
                        .font(.footnote)
                        .foregroundStyle(Color.moneyStalkerSlate)
                    ForEach(result.notes, id: \.self) { note in
                        Text(note).font(.footnote).foregroundStyle(Color.moneyStalkerSlate)
                    }
                    Text("Prices are manually entered. Gold source: \(goldSource.isEmpty ? "not named" : goldSource). Silver source: \(silverSource.isEmpty ? "not named" : silverSource).")
                        .font(.footnote)
                        .foregroundStyle(Color.moneyStalkerSlate)
                }
            }
            Section {
                Button("Calculate") { result = ZakatEngine.calculate(makeInput()) }
                Button("Save this estimate") { save() }
                    .disabled(result == nil)
            }
        }
        .navigationTitle("Zakat calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if result != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: summary()) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share estimate")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if padFocused {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(Color.moneyStalkerOnHero)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.moneyStalkerPrimary, in: Capsule())
                }
                .padding(.bottom, 20)
                .accessibilityLabel("Done")
            }
        }
        .alert("Zakat", isPresented: messageShown) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var code: String { appModel.settings.currencyCode }
    private var locale: Locale { appModel.settings.formattingLocale }
    private var messageShown: Binding<Bool> { Binding(get: { message != nil }, set: { if !$0 { message = nil } }) }

    private func moneyField(_ title: String, _ help: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            MoneyPadField(text: text, placeholder: "0", locale: locale, showsDone: false, isFocused: $padFocused)
            Text(help).font(.caption2).foregroundStyle(Color.moneyStalkerSlate)
        }
    }

    private func decimalField(_ title: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            MoneyPadField(text: text, placeholder: "0", locale: locale, showsDone: false, isFocused: $padFocused)
        }
    }

    private func line(_ title: String, _ minor: Int64) -> some View {
        LabeledContent(title, value: MoneyText.string(minor: minor, code: code, locale: locale))
    }

    private func minor(_ text: String) -> Int64 {
        MoneyInput.minorUnits(from: text, currencyCode: code, locale: locale) ?? 0
    }

    private func makeInput() -> ZakatInput {
        var input = ZakatInput()
        input.method = method
        input.hawlConfirmed = hawlConfirmed
        input.cashHomeMinor = minor(cash)
        input.bankMinor = minor(bank)
        input.investmentsMinor = minor(investments)
        input.moneyLentMinor = minor(lent)
        input.receivablesMinor = minor(receivables)
        input.businessCashMinor = minor(businessCash)
        input.inventoryMinor = minor(inventory)
        input.otherAssetsMinor = minor(other)
        input.includeRetirement = includeRetirement
        input.retirementMinor = minor(retirement)
        input.shortTermLiabilitiesMinor = minor(liabilities)
        input.paidInAdvanceMinor = minor(paid)
        input.goldGrams = ZakatEngine.decimal(from: goldGrams, locale: locale)
        input.goldKarat = ZakatEngine.decimal(from: goldKarat, locale: locale)
        input.goldPricePerGramMinor = minor(goldPrice)
        input.silverGrams = ZakatEngine.decimal(from: silverGrams, locale: locale)
        input.silverFineness = ZakatEngine.decimal(from: silverFineness, locale: locale)
        input.silverPricePerGramMinor = minor(silverPrice)
        return input
    }

    private func statusText(_ result: ZakatResult) -> String {
        switch result.status {
        case .missingPrice: "Zakat is not estimated as due because the selected nisab has no manual price."
        case .belowNisab: "Zakat is not estimated as due because net wealth is below nisab."
        case .hawlRequired: "Wealth meets nisab. Confirm hawl before this method estimates an amount due."
        case .due: "This method estimates zakat as due on the net wealth above, using 2.5%."
        }
    }

    private func summary() -> String {
        let current = result ?? ZakatEngine.calculate(makeInput())
        let money = { (value: Int64) in MoneyText.string(minor: value, code: code, locale: locale) }
        return """
        Money Stalker zakat estimate
        Method: \(method.title)
        Nisab weight: \(method == .gold ? "87.48 g gold" : "612.36 g silver")
        Eligible assets: \(money(current.eligibleAssetsMinor))
        Deductions: \(money(current.deductionsMinor))
        Net: \(money(current.netWealthMinor))
        Nisab: \(current.nisabMinor.map(money) ?? "not priced")
        Estimated zakat: \(money(current.zakatDueMinor))
        Remaining: \(money(current.remainingMinor))
        Gold price source: \(goldSource.isEmpty ? "manual, unnamed" : goldSource) on \(goldDate.formatted(date: .abbreviated, time: .omitted))
        Silver price source: \(silverSource.isEmpty ? "manual, unnamed" : silverSource) on \(silverDate.formatted(date: .abbreviated, time: .omitted))
        This is not a fatwa.
        """
    }

    private func save() {
        let current = ZakatEngine.calculate(makeInput())
        result = current
        let record = ZakatCalculationRecord(
            currencyCode: code,
            methodRaw: method.rawValue,
            hawlConfirmed: hawlConfirmed,
            hawlDate: hasHawlDate ? hawlDate : nil,
            cashHomeMinor: minor(cash),
            bankMinor: minor(bank),
            investmentsMinor: minor(investments),
            moneyLentMinor: minor(lent),
            receivablesMinor: minor(receivables),
            businessCashMinor: minor(businessCash),
            inventoryMinor: minor(inventory),
            otherAssetsMinor: minor(other),
            includeRetirement: includeRetirement,
            retirementMinor: minor(retirement),
            shortTermLiabilitiesMinor: minor(liabilities),
            paidInAdvanceMinor: minor(paid),
            goldGrams: goldGrams,
            goldKarat: goldKarat,
            goldPricePerGramMinor: minor(goldPrice),
            goldPriceSource: goldSource,
            goldPriceDate: goldDate,
            silverGrams: silverGrams,
            silverFineness: silverFineness,
            silverPricePerGramMinor: minor(silverPrice),
            silverPriceSource: silverSource,
            silverPriceDate: silverDate,
            eligibleAssetsMinor: current.eligibleAssetsMinor,
            deductionsMinor: current.deductionsMinor,
            netWealthMinor: current.netWealthMinor,
            nisabMinor: current.nisabMinor ?? 0,
            nisabKnown: current.nisabMinor != nil,
            zakatDueMinor: current.zakatDueMinor,
            remainingMinor: current.remainingMinor,
            statusRaw: current.status.rawValue,
            notes: current.notes,
            engineVersion: ZakatInput.engineVersion
        )
        context.insert(record)
        do {
            try context.save()
            scheduleHawl(record)
            message = "Estimate saved. Later price changes will not rewrite this snapshot."
        } catch {
            message = error.localizedDescription
        }
    }

    private func scheduleHawl(_ record: ZakatCalculationRecord) {
        guard let start = record.hawlDate else { return }
        let fire = Calendar.current.date(byAdding: .day, value: 354, to: start) ?? start
        guard fire > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Zakat hawl reminder"
        content.body = "About 354 days have passed since the hawl date you saved. Check the estimate before you rely on it."
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let request = UNNotificationRequest(identifier: "moneyStalker.zakat.hawl.\(record.id.uuidString)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}
