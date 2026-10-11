import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @State private var page = 0
    @State private var name = "Cash"
    @State private var type: AccountType = .cash
    @State private var currency = ""
    @State private var opening = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= page ? Color.moneyStalkerPrimary : Color.moneyStalkerBorder)
                        .frame(height: 4)
                }
            }
            .padding(.top, 12)
            .animation(ChartMotion.spring, value: page)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(page + 1) of 3")

            Spacer(minLength: 8)
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.moneyStalkerOnHero)
                .frame(width: 84, height: 84)
                .background { MoneyStalkerMesh(style: .hero) }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            if page == 0 {
                welcome
            } else if page == 1 {
                privacy
            } else {
                accountForm
            }
            Spacer(minLength: 8)
            PrimaryButton(title: page < 2 ? "Continue" : "Start tracking", enabled: page < 2 || !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                if page < 2 { page += 1 } else { create() }
            }
            if page > 0 {
                Button("Back") { page -= 1 }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
            if let error {
                Text(error).font(.footnote).foregroundStyle(Color.moneyStalkerExpense)
            }
        }
        .padding(24)
        .moneyStalkerScreen()
        .animation(.snappy, value: page)
        .onAppear {
            if currency.isEmpty { currency = appModel.settings.currencyCode }
        }
    }

    private var icon: String {
        switch page {
        case 0: "leaf.fill"
        case 1: "lock.shield.fill"
        default: "wallet.pass.fill"
        }
    }

    private var welcome: some View {
        VStack(spacing: 10) {
            Text("Welcome to Money Stalker")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.moneyStalkerSecondary)
            Text("Track balances, spending, and budgets. Everything you save stays on this iPhone.")
                .font(.body)
                .foregroundStyle(Color.moneyStalkerSlate)
                .multilineTextAlignment(.center)
        }
    }

    private var privacy: some View {
        VStack(spacing: 10) {
            Text("Private by default")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.moneyStalkerSecondary)
            Text("No account to create and no cloud sync. You can lock the app with Face ID and export a backup whenever you want.")
                .font(.body)
                .foregroundStyle(Color.moneyStalkerSlate)
                .multilineTextAlignment(.center)
        }
    }

    private var accountForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your first account")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.moneyStalkerSecondary)
            Text("This is where balances start. You can add more accounts later.")
                .font(.subheadline)
                .foregroundStyle(Color.moneyStalkerSlate)
            field("Account name", text: $name)
            Picker("Type", selection: $type) {
                ForEach(AccountType.allCases) { item in Text(item.title).tag(item) }
            }
            .pickerStyle(.menu)
            Picker("Currency", selection: $currency) {
                ForEach(CurrencyCatalog.common) { item in Text(item.code).tag(item.code) }
            }
            .pickerStyle(.menu)
            field("Opening balance", text: $opening, decimal: true)
            Text("Use the amount already in this account, before any transactions.")
                .font(.caption)
                .foregroundStyle(Color.moneyStalkerSlate)
        }
    }

    private func field(_ title: String, text: Binding<String>, decimal: Bool = false) -> some View {
        Group {
            if decimal {
                MoneyPadField(text: text, placeholder: title, locale: appModel.settings.formattingLocale)
            } else {
                TextField(title, text: text)
            }
        }
            .padding(14)
            .background(Color.moneyStalkerCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.moneyStalkerBorder, lineWidth: 1))
    }

    private func create() {
        let minor = MoneyInput.minorUnits(from: opening.isEmpty ? "0" : opening, currencyCode: currency, locale: appModel.settings.formattingLocale) ?? 0
        guard minor >= 0 || opening.isEmpty else {
            error = "Enter a valid opening balance."
            return
        }
        let parsed = opening.isEmpty ? 0 : (MoneyInput.minorUnits(from: opening, currencyCode: currency, locale: appModel.settings.formattingLocale) ?? -1)
        guard parsed >= 0 else {
            error = "Enter a valid opening balance."
            return
        }
        let account = Account(name: name.trimmingCharacters(in: .whitespaces), type: type, openingBalanceMinor: parsed, currencyCode: currency, icon: type.symbol, colorHex: "1877F2")
        context.insert(account)
        do {
            try context.save()
            appModel.settings.currencyCode = currency
            appModel.settings.lastAccountID = account.id.uuidString
            appModel.settings.hasCompletedOnboarding = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct LockView: View {
    @Environment(AppModel.self) private var appModel
    @State private var message = "Money Stalker is locked."

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.moneyStalkerOnHero)
                .frame(width: 84, height: 84)
                .background { MoneyStalkerMesh(style: .hero) }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            Text("Money Stalker")
                .font(.largeTitle.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.moneyStalkerSlate)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Unlock", systemImage: "faceid") { Task { await unlock() } }
            Text("Face ID or Touch ID is used when available. Otherwise Money Stalker asks for the device passcode so you are not locked out.")
                .font(.caption)
                .foregroundStyle(Color.moneyStalkerSlate)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(28)
        .moneyStalkerScreen()
        .task { await unlock() }
    }

    private func unlock() async {
        if let failure = await BiometricLock.unlock() {
            message = failure
        } else {
            appModel.isLocked = false
        }
    }
}
