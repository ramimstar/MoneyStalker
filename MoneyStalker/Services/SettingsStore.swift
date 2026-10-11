import Foundation

enum FormattingLanguage: String, CaseIterable, Identifiable {
    case system, english, bengali
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .bengali: "বাংলা"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .current
        case .english: Locale(identifier: "en_US")
        case .bengali: Locale(identifier: "bn_BD")
        }
    }
}

enum DateDisplayStyle: String, CaseIterable, Identifiable {
    case system, medium, dayMonthYear, monthDayYear, iso
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .medium: "Medium"
        case .dayMonthYear: "DD/MM/YYYY"
        case .monthDayYear: "MM/DD/YYYY"
        case .iso: "ISO"
        }
    }
}

enum WeekStart: String, CaseIterable, Identifiable {
    case sunday, monday
    var id: String { rawValue }
    var title: String { self == .monday ? "Monday" : "Sunday" }
    var firstWeekday: Int { self == .monday ? 2 : 1 }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum DateFormatting {
    static func string(from date: Date, style: DateDisplayStyle, locale: Locale, calendar: Calendar, includeTime: Bool = false) -> String {
        switch style {
        case .iso:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = includeTime ? [.withFullDate, .withTime, .withColonSeparatorInTime] : [.withFullDate]
            formatter.timeZone = calendar.timeZone
            return formatter.string(from: date)
        case .dayMonthYear, .monthDayYear:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = locale
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = style == .dayMonthYear ? (includeTime ? "dd/MM/yyyy HH:mm" : "dd/MM/yyyy") : (includeTime ? "MM/dd/yyyy HH:mm" : "MM/dd/yyyy")
            return formatter.string(from: date)
        case .system, .medium:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = locale
            formatter.timeZone = calendar.timeZone
            formatter.dateStyle = style == .system ? .medium : .medium
            formatter.timeStyle = includeTime ? .short : .none
            return formatter.string(from: date)
        }
    }
}

@MainActor
@Observable
final class SettingsStore {
    private enum Key {
        static let currency = "moneyStalker.currency"
        static let language = "moneyStalker.language"
        static let dateStyle = "moneyStalker.dateStyle"
        static let weekStart = "moneyStalker.weekStart"
        static let appearance = "moneyStalker.appearance"
        static let theme = "moneyStalker.theme"
        static let onboarding = "moneyStalker.onboarding"
        static let notifications = "moneyStalker.notifications"
        static let budgetAlerts = "moneyStalker.budgetAlerts"
        static let recurringReminders = "moneyStalker.recurringReminders"
        static let debtReminders = "moneyStalker.debtReminders"
        static let smartNotifications = "moneyStalker.smartNotifications"
        static let rates = "moneyStalker.rates"
        static let lastAccount = "moneyStalker.lastAccount"
        static let lastExpenseCategory = "moneyStalker.lastExpenseCategory"
        static let lastIncomeCategory = "moneyStalker.lastIncomeCategory"
    }

    private let defaults: UserDefaults
    private var isLoading = true

    var currencyCode: String { didSet { persist() } }
    var formattingLanguage: FormattingLanguage { didSet { persist() } }
    var dateStyle: DateDisplayStyle { didSet { persist() } }
    var weekStart: WeekStart { didSet { persist() } }
    var appearance: AppearanceMode { didSet { persist() } }
    var theme: AppTheme { didSet { persist() } }
    var hasCompletedOnboarding: Bool { didSet { persist() } }
    var notificationsEnabled: Bool { didSet { persist() } }
    var budgetAlertsEnabled: Bool { didSet { persist() } }
    var recurringRemindersEnabled: Bool { didSet { persist() } }
    var debtRemindersEnabled: Bool { didSet { persist() } }
    var smartNotifications: SmartNotificationSettings { didSet { persist() } }
    var exchangeRates: [String: String] { didSet { persist() } }
    var lastAccountID: String { didSet { persist() } }
    var lastExpenseCategoryID: String { didSet { persist() } }
    var lastIncomeCategoryID: String { didSet { persist() } }
    var appLockEnabled: Bool { didSet { persistLock() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currencyCode = defaults.string(forKey: Key.currency) ?? Locale.current.currency?.identifier ?? "USD"
        formattingLanguage = FormattingLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system
        dateStyle = DateDisplayStyle(rawValue: defaults.string(forKey: Key.dateStyle) ?? "") ?? .system
        weekStart = WeekStart(rawValue: defaults.string(forKey: Key.weekStart) ?? "") ?? .sunday
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        theme = AppTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .glacier
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarding)
        notificationsEnabled = defaults.bool(forKey: Key.notifications)
        budgetAlertsEnabled = Self.storedBool(defaults, Key.budgetAlerts, default: true)
        recurringRemindersEnabled = Self.storedBool(defaults, Key.recurringReminders, default: true)
        debtRemindersEnabled = Self.storedBool(defaults, Key.debtReminders, default: true)
        if let data = defaults.data(forKey: Key.smartNotifications),
           let decoded = try? JSONDecoder().decode(SmartNotificationSettings.self, from: data) {
            smartNotifications = decoded
        } else {
            smartNotifications = SmartNotificationSettings()
        }
        if let data = defaults.data(forKey: Key.rates),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            exchangeRates = decoded
        } else {
            exchangeRates = [:]
        }
        lastAccountID = defaults.string(forKey: Key.lastAccount) ?? ""
        lastExpenseCategoryID = defaults.string(forKey: Key.lastExpenseCategory) ?? ""
        lastIncomeCategoryID = defaults.string(forKey: Key.lastIncomeCategory) ?? ""
        appLockEnabled = KeychainStore.data(for: "app-lock") == Data([1])
        isLoading = false
    }

    var formattingLocale: Locale { formattingLanguage.locale }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = formattingLocale
        calendar.timeZone = .current
        calendar.firstWeekday = weekStart.firstWeekday
        return calendar
    }

    var colorScheme: String { appearance.rawValue }

    var parsedRates: [String: Decimal] { CurrencyConverter.parseRates(exchangeRates) }

    func applyBackup(_ settings: SettingsDTO) {
        currencyCode = settings.currencyCode
        weekStart = WeekStart(rawValue: settings.weekStart) ?? weekStart
        dateStyle = DateDisplayStyle(rawValue: settings.dateStyle) ?? dateStyle
        formattingLanguage = FormattingLanguage(rawValue: settings.formattingLanguage) ?? formattingLanguage
        exchangeRates = settings.exchangeRates
    }

    func backupDTO() -> SettingsDTO {
        SettingsDTO(
            currencyCode: currencyCode,
            weekStart: weekStart.rawValue,
            dateStyle: dateStyle.rawValue,
            formattingLanguage: formattingLanguage.rawValue,
            exchangeRates: exchangeRates
        )
    }

    func resetFinancialPreferences() {
        hasCompletedOnboarding = false
        exchangeRates = [:]
        lastAccountID = ""
        lastExpenseCategoryID = ""
        lastIncomeCategoryID = ""
    }

    private func persist() {
        guard !isLoading else { return }
        defaults.set(currencyCode, forKey: Key.currency)
        defaults.set(formattingLanguage.rawValue, forKey: Key.language)
        defaults.set(dateStyle.rawValue, forKey: Key.dateStyle)
        defaults.set(weekStart.rawValue, forKey: Key.weekStart)
        defaults.set(appearance.rawValue, forKey: Key.appearance)
        defaults.set(theme.rawValue, forKey: Key.theme)
        defaults.set(hasCompletedOnboarding, forKey: Key.onboarding)
        defaults.set(notificationsEnabled, forKey: Key.notifications)
        defaults.set(budgetAlertsEnabled, forKey: Key.budgetAlerts)
        defaults.set(recurringRemindersEnabled, forKey: Key.recurringReminders)
        defaults.set(debtRemindersEnabled, forKey: Key.debtReminders)
        if let data = try? JSONEncoder().encode(smartNotifications) {
            defaults.set(data, forKey: Key.smartNotifications)
        }
        defaults.set(lastAccountID, forKey: Key.lastAccount)
        defaults.set(lastExpenseCategoryID, forKey: Key.lastExpenseCategory)
        defaults.set(lastIncomeCategoryID, forKey: Key.lastIncomeCategory)
        if let data = try? JSONEncoder().encode(exchangeRates) {
            defaults.set(data, forKey: Key.rates)
        }
    }

    var notificationPreferences: NotificationPreferences {
        NotificationPreferences(
            enabled: notificationsEnabled,
            budgetAlertsEnabled: budgetAlertsEnabled,
            recurringRemindersEnabled: recurringRemindersEnabled,
            billRemindersEnabled: debtRemindersEnabled,
            smart: smartNotifications
        )
    }

    private static func storedBool(_ defaults: UserDefaults, _ key: String, default defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private func persistLock() {
        guard !isLoading else { return }
        if appLockEnabled {
            try? KeychainStore.set(Data([1]), for: "app-lock")
        } else {
            KeychainStore.remove("app-lock")
        }
    }
}
