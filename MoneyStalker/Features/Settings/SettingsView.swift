import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DataFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data
    var contentType: UTType = .json

    init(data: Data, contentType: UTType = .json) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @Query private var transactions: [LedgerTransaction]
    @Query private var categories: [Category]

    @State private var exportFile: DataFile?
    @State private var exportType: UTType = .json
    @State private var exportName = "Money Stalker"
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingRestore: Data?
    @State private var confirmRestore = false
    @State private var confirmDelete = false
    @State private var otherCurrency = ""
    @State private var message: String?
    @State private var working = false

    var body: some View {
        @Bindable var settings = appModel.settings
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image("BalanceBag")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Money Stalker")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.moneyStalkerSecondary)
                            Text("On this iPhone")
                                .font(.subheadline)
                                .foregroundStyle(Color.moneyStalkerSlate)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    Picker(selection: $settings.currencyCode) {
                        ForEach(CurrencyCatalog.common) { Text(itemLabel($0)).tag($0.code) }
                    } label: {
                        SettingsLabel(title: "Currency", symbol: "dollarsign", tint: SettingsTint.green)
                    }
                    HStack(spacing: 12) {
                        SettingsSymbol(name: "plus", tint: SettingsTint.teal)
                        TextField("Other ISO code", text: $otherCurrency)
                            .textInputAutocapitalization(.characters)
                            .onSubmit { applyOtherCurrency() }
                    }
                    Picker(selection: $settings.formattingLanguage) {
                        ForEach(FormattingLanguage.allCases) { Text($0.title).tag($0) }
                    } label: {
                        SettingsLabel(title: "Language", symbol: "globe", tint: SettingsTint.blue)
                    }
                    Picker(selection: $settings.dateStyle) {
                        ForEach(DateDisplayStyle.allCases) { Text($0.title).tag($0) }
                    } label: {
                        SettingsLabel(title: "Dates", symbol: "calendar", tint: SettingsTint.red)
                    }
                    Picker(selection: $settings.weekStart) {
                        ForEach(WeekStart.allCases) { Text($0.title).tag($0) }
                    } label: {
                        SettingsLabel(title: "Week starts", symbol: "calendar.badge.clock", tint: SettingsTint.orange)
                    }
                    Picker(selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                    } label: {
                        SettingsLabel(title: "Appearance", symbol: "circle.lefthalf.filled", tint: SettingsTint.indigo)
                    }
                    NavigationLink {
                        ThemesView()
                    } label: {
                        SettingsLabel(title: "Themes", symbol: "paintpalette.fill", tint: SettingsTint.pink)
                    }
                } header: {
                    Text("Money")
                } footer: {
                    Text("Language changes dates and numbers. Screen text stays in English.")
                }
                Section {
                    if foreignCurrencies.isEmpty {
                        SettingsLabel(title: "No other currencies yet", symbol: "arrow.left.arrow.right", tint: SettingsTint.gray)
                    } else {
                        ForEach(foreignCurrencies, id: \.self) { code in
                            HStack(spacing: 12) {
                                SettingsSymbol(name: "arrow.left.arrow.right", tint: SettingsTint.green)
                                MoneyPadField(text: rateBinding(code), placeholder: "1 \(code)", locale: appModel.settings.formattingLocale)
                            }
                        }
                    }
                } header: {
                    Text("Exchange rates")
                } footer: {
                    Text("Enter how many \(settings.currencyCode) equal 1 unit of the other currency. Money Stalker does not guess rates, and it will not add mixed currencies without one.")
                }
                Section("Library") {
                    settingsLink("Accounts", "creditcard.fill", SettingsTint.blue, AppRoute.accounts)
                    settingsLink("Categories", "square.grid.2x2.fill", SettingsTint.orange, AppRoute.categories)
                    settingsLink("Recurring", "repeat", SettingsTint.purple, AppRoute.recurringList)
                    settingsLink("Savings goals", "target", SettingsTint.green, AppRoute.goals)
                    settingsLink("Debts", "person.2.fill", SettingsTint.red, AppRoute.debts)
                    settingsLink("Calendar", "calendar", SettingsTint.pink, AppRoute.calendar)
                }
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsLabel(title: "Notifications", symbol: "bell.badge.fill", tint: SettingsTint.red, value: settings.notificationsEnabled ? "On" : "Off")
                    }
                } footer: {
                    Text("Reminders stay on this iPhone. Daily and weekly summaries use the transactions saved the last time Money Stalker prepared them.")
                }
                Section {
                    Toggle(isOn: lockBinding) {
                        SettingsLabel(title: "App lock", symbol: "faceid", tint: SettingsTint.blue)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Face ID or Touch ID protects the app. The choice is stored in the Keychain. Money Stalker does not store a password.")
                }
                Section {
                    settingsButton("Export backup", "square.and.arrow.up.fill", SettingsTint.blue, exportBackup)
                    settingsButton("Export transactions CSV", "tablecells.fill", SettingsTint.green, exportCSV)
                    settingsButton("Export summary", "doc.text.fill", SettingsTint.indigo, exportSummary)
                    settingsButton("Restore backup", "square.and.arrow.down.fill", SettingsTint.orange) { showImporter = true }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Restore replaces data on this iPhone. CSV is for spreadsheets and is not imported.")
                }
                Section {
                    NavigationLink { PrivacyView() } label: {
                        SettingsLabel(title: "Privacy", symbol: "hand.raised.fill", tint: SettingsTint.blue)
                    }
                    NavigationLink { AboutView() } label: {
                        SettingsLabel(title: "About", symbol: "info.circle.fill", tint: SettingsTint.gray)
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        HStack(spacing: 12) {
                            SettingsSymbol(name: "trash.fill", tint: SettingsTint.red)
                            Text("Delete all local data")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .moneyStalkerScreen()
            .moneyStalkerHidesTabBar(.settings)
            .navigationTitle("Settings")
            .moneyStalkerDestinations()
            .overlay { if working { LoadingView(title: "Working") } }
            .fileExporter(isPresented: $showExporter, document: exportFile, contentType: exportType, defaultFilename: exportName) { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        pendingRestore = try Data(contentsOf: url)
                        _ = try BackupCodec.decode(pendingRestore ?? Data())
                        confirmRestore = true
                    } catch {
                        message = error.localizedDescription
                        pendingRestore = nil
                    }
                case .failure(let error):
                    message = error.localizedDescription
                }
            }
            .moneyStalkerConfirmation(isPresented: $confirmRestore, title: "Replace all data?", message: "This replaces accounts, transactions, budgets, schedules, goals, and debts on this iPhone with the backup.", confirmTitle: "Replace") {
                restore()
            }
            .moneyStalkerConfirmation(isPresented: $confirmDelete, title: "Delete all local data?", message: "This cannot be undone. Export a backup first if you want a copy.", confirmTitle: "Delete") {
                wipe()
            }
            .alert("Money Stalker", isPresented: messageShown) { Button("OK", role: .cancel) { message = nil } } message: { Text(message ?? "") }
        }
    }

    private var foreignCurrencies: [String] {
        Array(Set(accounts.map(\.currencyCode))).filter { $0 != appModel.settings.currencyCode }.sorted()
    }

    private var messageShown: Binding<Bool> { Binding(get: { message != nil }, set: { if !$0 { message = nil } }) }

    private var lockBinding: Binding<Bool> {
        Binding(get: { appModel.settings.appLockEnabled }, set: { newValue in
            if newValue {
                Task {
                    if await BiometricLock.unlock() == nil {
                        appModel.settings.appLockEnabled = true
                    } else {
                        message = "App lock was not turned on."
                    }
                }
            } else {
                appModel.settings.appLockEnabled = false
                appModel.isLocked = false
            }
        })
    }

    private func settingsLink(_ title: String, _ symbol: String, _ tint: Color, _ route: AppRoute) -> some View {
        NavigationLink(value: route) {
            SettingsLabel(title: title, symbol: symbol, tint: tint)
        }
    }

    private func settingsButton(_ title: String, _ symbol: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsLabel(title: title, symbol: symbol, tint: tint)
        }
        .foregroundStyle(Color.moneyStalkerSecondary)
    }

    private func itemLabel(_ info: CurrencyInfo) -> String { "\(info.code) · \(info.name)" }

    private func rateBinding(_ code: String) -> Binding<String> {
        Binding(get: { appModel.settings.exchangeRates[code] ?? "" }, set: { appModel.settings.exchangeRates[code] = $0 })
    }

    private func applyOtherCurrency() {
        let code = otherCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard CurrencyCatalog.isKnownISOCode(code) else { message = "Use a three-letter currency code."; return }
        appModel.settings.currencyCode = code
    }

    private func exportBackup() {
        do {
            let data = try BackupService.exportData(context: context, settings: appModel.settings)
            exportFile = DataFile(data: data, contentType: .json)
            exportType = .json
            exportName = "MoneyStalkerBackup"
            showExporter = true
        } catch { message = error.localizedDescription }
    }

    private func exportCSV() {
        let csv = CSVExporter.transactions(transactions.map(\.snapshot), accounts: accounts.map(\.snapshot), categories: categories.map(\.snapshot))
        exportFile = DataFile(data: Data(csv.utf8), contentType: .commaSeparatedText)
        exportType = .commaSeparatedText
        exportName = "MoneyStalkerTransactions"
        showExporter = true
    }

    private func exportSummary() {
        let net = LedgerCalculator.netWorth(accounts: accounts.map(\.snapshot), transactions: transactions.map(\.snapshot), preferredCurrency: appModel.settings.currencyCode, rates: appModel.settings.parsedRates, includeArchived: true)
        let window = PeriodMath.window(preset: .month, customStart: .now, customEnd: .now, now: .now, calendar: appModel.settings.calendar)
        let flow = LedgerCalculator.cashflow(transactions: transactions.map(\.snapshot), window: window, currencyCode: appModel.settings.currencyCode)
        let text = CSVExporter.summary(netWorth: net, cashflow: flow, locale: appModel.settings.formattingLocale)
        exportFile = DataFile(data: Data(text.utf8), contentType: .plainText)
        exportType = .plainText
        exportName = "MoneyStalkerSummary"
        showExporter = true
    }

    private func restore() {
        guard let pendingRestore else { return }
        working = true
        do {
            try BackupService.restore(data: pendingRestore, context: context, settings: appModel.settings, directory: BackupService.supportDirectory())
            message = "Backup restored."
        } catch {
            message = error.localizedDescription
        }
        working = false
        self.pendingRestore = nil
    }

    private func wipe() {
        do {
            try DataWipe.eraseEverything(context: context, settings: appModel.settings)
        } catch { message = error.localizedDescription }
    }

}

struct PrivacyView: View {
    var body: some View {
        Form {
            Section {
                privacyRow("On this iPhone", "iphone", SettingsTint.blue, "Your records stay on this iPhone. Money Stalker does not require an account and does not sync to a cloud service.")
            }
            Section {
                privacyRow("Storage", "internaldrive.fill", SettingsTint.gray, "SwiftData stores the database in the app’s local storage. That is not a separate encryption layer. iOS protects the app’s files with your device passcode.")
                privacyRow("App lock", "faceid", SettingsTint.blue, "App lock uses Face ID, Touch ID, or the device passcode. The on/off choice is kept in the Keychain. No password is stored.")
                privacyRow("Photos", "photo.fill", SettingsTint.pink, "Receipt photos are copied into the local database only after you choose them.")
                privacyRow("Notifications", "bell.badge.fill", SettingsTint.red, "Notifications are scheduled only after you allow them.")
            }
            Section {
                privacyRow("Export", "square.and.arrow.up.fill", SettingsTint.indigo, "Export and delete are in Settings. A backup file contains your financial records, so share it only with people you trust. CSV export is a spreadsheet copy, not a secure vault.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .moneyStalkerScreen()
        .navigationTitle("Privacy")
    }

    private func privacyRow(_ title: String, _ symbol: String, _ tint: Color, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsLabel(title: title, symbol: symbol, tint: tint)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color.moneyStalkerSlate)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                SettingsLabel(title: "Version", symbol: "number", tint: SettingsTint.blue, value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Text("Money Stalker is an offline personal finance manager. Totals come from opening balances and the transactions you save.")
                    .font(.footnote)
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
            Section("What this version does not do") {
                aboutRow("No cloud sync", "icloud.slash.fill", SettingsTint.gray)
                aboutRow("No extra database encryption", "lock.open.fill", SettingsTint.orange)
                aboutRow("Interest is not calculated", "percent", SettingsTint.purple)
                aboutRow("Rates are only the ones you enter", "arrow.left.arrow.right", SettingsTint.green)
                aboutRow("Schedules post when the app opens", "clock.fill", SettingsTint.blue)
                aboutRow("Screen text stays in English", "character.book.closed.fill", SettingsTint.indigo)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .moneyStalkerScreen()
        .navigationTitle("About")
    }

    private func aboutRow(_ title: String, _ symbol: String, _ tint: Color) -> some View {
        SettingsLabel(title: title, symbol: symbol, tint: tint)
    }
}

enum SettingsTint {
    static let blue = Color(red: 0.38, green: 0.66, blue: 1.00)
    static let green = Color(red: 0.45, green: 0.84, blue: 0.55)
    static let red = Color(red: 1.00, green: 0.48, blue: 0.45)
    static let orange = Color(red: 1.00, green: 0.72, blue: 0.38)
    static let purple = Color(red: 0.78, green: 0.55, blue: 0.93)
    static let indigo = Color(red: 0.55, green: 0.54, blue: 0.91)
    static let teal = Color(red: 0.42, green: 0.80, blue: 0.86)
    static let gray = Color(red: 0.72, green: 0.72, blue: 0.75)
    static let pink = Color(red: 1.00, green: 0.50, blue: 0.60)
}

struct SettingsSymbol: View {
    var name: String
    var tint: Color

    var body: some View {
        Image(uiImage: icon)
            .frame(width: 30, height: 30)
            .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }

    private var icon: UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image = UIImage(systemName: name, withConfiguration: configuration) ?? UIImage()
        return image.withTintColor(.white, renderingMode: .alwaysOriginal)
    }
}

struct SettingsLabel: View {
    var title: String
    var symbol: String
    var tint: Color
    var value: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            SettingsSymbol(name: symbol, tint: tint)
            Text(title)
                .foregroundStyle(Color.moneyStalkerSecondary)
            if value != nil { Spacer(minLength: 8) }
            if let value {
                Text(value)
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
        }
    }
}
