import SwiftUI
import UIKit

enum SoftwareKeyboard {
    /// The Simulator can attach the Mac keyboard and hide the on-screen keypad.
    /// Clearing that layout asks the Simulator to show the keypad. A real iPhone is unchanged.
    static func preferOnScreenKeypad() {
        #if targetEnvironment(simulator)
        let selector = NSSelectorFromString("setHardwareLayout:")
        for mode in UITextInputMode.activeInputModes where mode.responds(to: selector) {
            mode.perform(selector, with: nil)
        }
        #endif
    }
}

struct PrimaryButton: View {
    var title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Color.moneyStalkerOnHero)
            .background(enabled ? Color.moneyStalkerPrimary : Color.moneyStalkerSlate.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!enabled)
        .accessibilityHint(title)
    }
}

struct AmountTextField: View {
    @Binding var text: String
    var currencyCode: String
    var locale: Locale
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48

    var body: some View {
        VStack(spacing: 6) {
            Text(currencyCode)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerSlate)
            MoneyPadField(
                text: $text,
                placeholder: "0",
                locale: locale,
                font: roundedFont(size: size),
                alignment: .center,
                textColor: UIColor(Color.moneyStalkerSecondary),
                showsDone: false
            )
            .accessibilityLabel("Amount")
        }
    }

    private func roundedFont(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .semibold)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

private extension UIView {
    var firstResponderView: UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let match = subview.firstResponderView { return match }
        }
        return nil
    }
}

/// Forces the decimal number pad. SwiftUI's keyboard type is ignored inside forms.
struct MoneyPadField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var locale: Locale
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var alignment: NSTextAlignment = .natural
    var textColor: UIColor = .label
    var showsDone: Bool = true
    var isFocused: Binding<Bool> = .constant(false)

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .decimalPad
        field.delegate = context.coordinator
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.autocapitalizationType = .none
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.textContentType = nil
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        if showsDone {
            let bar = UIToolbar()
            bar.items = [
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.done))
            ]
            bar.sizeToFit()
            field.inputAccessoryView = bar
        }
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text { uiView.text = text }
        uiView.placeholder = placeholder
        uiView.font = font
        uiView.textAlignment = alignment
        uiView.textColor = textColor
        uiView.keyboardType = .decimalPad
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.intrinsicContentSize.width
        let height = max(uiView.intrinsicContentSize.height, 22)
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MoneyPadField

        init(_ parent: MoneyPadField) {
            self.parent = parent
        }

        @objc func changed(_ field: UITextField) {
            let sanitized = MoneyInput.sanitize(field.text ?? "", locale: parent.locale)
            if field.text != sanitized { field.text = sanitized }
            parent.text = sanitized
        }

        @objc func done() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused.wrappedValue = true
            SoftwareKeyboard.preferOnScreenKeypad()
            textField.reloadInputViews()
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            DispatchQueue.main.async { [weak textField] in
                guard let textField else { return }
                if Self.anotherFieldIsEditing(besides: textField) { return }
                self.parent.isFocused.wrappedValue = false
            }
        }

        private static func anotherFieldIsEditing(besides field: UITextField) -> Bool {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            return windows.contains { window in
                guard let responder = window.firstResponderView, responder !== field else { return false }
                return responder is UITextField
            }
        }
    }
}

struct CurrencyAmountView: View {
    var minor: Int64
    var currencyCode: String
    var locale: Locale
    var emphasis: Emphasis = .standard

    enum Emphasis { case hero, large, standard, compact }

    var body: some View {
        Text(MoneyText.string(minor: minor, code: currencyCode, locale: locale))
            .font(font)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .monospacedDigit()
            .contentTransition(.numericText())
            .accessibilityLabel(MoneyText.string(minor: minor, code: currencyCode, locale: locale))
    }

    private var font: Font {
        switch emphasis {
        case .hero: .system(size: 40, weight: .bold, design: .rounded)
        case .large: .system(size: 28, weight: .semibold, design: .rounded)
        case .standard: .headline
        case .compact: .subheadline.weight(.semibold)
        }
    }
}

struct CategoryIcon: View {
    var systemName: String
    var hex: String
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Color(moneyStalkerHex: hex))
            .frame(width: size, height: size)
            .background(Color(moneyStalkerHex: hex).opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SummaryCard: View {
    var title: String
    var minor: Int64
    var currencyCode: String
    var locale: Locale
    var caption: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerSlate)
            CurrencyAmountView(minor: minor, currencyCode: currencyCode, locale: locale, emphasis: .standard)
                .foregroundStyle(tint)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Color.moneyStalkerSlate)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyStalkerCard(graph: .wave)
        .accessibilityElement(children: .combine)
    }
}

struct AccountCard: View {
    var account: Account
    var balanceMinor: Int64
    var locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CategoryIcon(systemName: account.icon, hex: account.colorHex, size: 34)
                Spacer()
                Text(account.type == .custom && !account.customTypeName.isEmpty ? account.customTypeName : account.type.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
            Text(account.name)
                .font(.headline)
                .foregroundStyle(Color.moneyStalkerSecondary)
                .lineLimit(1)
            CurrencyAmountView(minor: balanceMinor, currencyCode: account.currencyCode, locale: locale, emphasis: .standard)
                .foregroundStyle(balanceMinor < 0 ? Color.moneyStalkerExpense : Color.moneyStalkerSecondary)
            if account.type == .credit && account.creditLimitMinor > 0 && balanceMinor < 0 {
                let used = min(1, Double(abs(balanceMinor)) / Double(account.creditLimitMinor))
                Text("\(MoneyText.percent(basisPoints: min(10_000, (abs(balanceMinor) * 10_000) / account.creditLimitMinor))) of limit")
                    .font(.caption2)
                    .foregroundStyle(Color.moneyStalkerSlate)
                RangeFill(progress: used, tint: used >= 0.8 ? Color.moneyStalkerWarning : Color(moneyStalkerHex: account.colorHex), height: 6)
            }
        }
        .frame(width: 210, alignment: .leading)
        .moneyStalkerCard(graph: .dots)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.name), \(MoneyText.string(minor: balanceMinor, code: account.currencyCode, locale: locale))")
    }
}

struct TransactionRow: View {
    var transaction: LedgerTransaction
    var locale: Locale

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(
                systemName: transaction.category?.icon ?? transaction.subcategory?.icon ?? symbol,
                hex: transaction.category?.colorHex ?? transaction.subcategory?.colorHex ?? fallbackHex,
                size: 40
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.moneyStalkerSlate)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(amount)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(transaction.type.title)
                    .font(.caption2)
                    .foregroundStyle(Color.moneyStalkerSlate)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if transaction.type == .transfer {
            let from = transaction.account?.name ?? "Account"
            let to = transaction.counterAccount?.name ?? "Account"
            return "\(from) to \(to)"
        }
        return transaction.subcategory?.name ?? transaction.category?.name ?? transaction.type.title
    }

    private var subtitle: String {
        let account = transaction.account?.name ?? "No account"
        if transaction.notes.isEmpty { return account }
        return "\(account) · \(transaction.notes)"
    }

    private var amount: String {
        let prefix: String
        switch transaction.type {
        case .income: prefix = "+"
        case .expense: prefix = "−"
        case .transfer, .principal: prefix = ""
        }
        return prefix + MoneyText.string(minor: transaction.amountMinor, code: transaction.currencyCode, locale: locale)
    }

    private var tint: Color {
        switch transaction.type {
        case .income: Color.moneyStalkerIncome
        case .expense: Color.moneyStalkerExpense
        case .transfer, .principal: Color.moneyStalkerSlate
        }
    }

    private var symbol: String {
        switch transaction.type {
        case .income: "arrow.down.left"
        case .expense: "arrow.up.right"
        case .transfer: "arrow.left.arrow.right"
        case .principal: "person.2"
        }
    }

    private var fallbackHex: String {
        switch transaction.type {
        case .income: "1B7F45"
        case .expense: "D85745"
        default: "5C6770"
        }
    }
}

struct BudgetProgressCard: View {
    var status: BudgetStatus
    var locale: Locale
    var systemName: String = "chart.pie.fill"
    var colorHex: String = "1B7F45"
    var graph: CardGraphKind = .columns

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
                    Text(status.name)
                        .font(.headline)
                        .foregroundStyle(Color.moneyStalkerSecondary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.moneyStalkerSlate)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 3) {
                    Image(systemName: status.isOverBudget || status.isWarning ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.weight(.bold))
                    Text(MoneyText.percent(basisPoints: status.consumedBasisPoints))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
                .foregroundStyle(barColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(barColor.opacity(0.12))
                .clipShape(Capsule())
            }
            Text(money(status.spentMinor))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.moneyStalkerSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            RangeFill(progress: min(1, Double(status.consumedBasisPoints) / 10_000), tint: barColor)
            HStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.caption2)
                Text(footer)
                    .font(.caption)
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

    private var subtitle: String {
        if status.isOverBudget { return "Over your limit" }
        if status.isWarning { return "Close to your limit" }
        return "On plan"
    }

    private var footer: String {
        if status.remainingMinor >= 0 {
            return "Left  •  \(money(status.remainingMinor))"
        }
        return "Over spent  •  \(money(abs(status.remainingMinor)))"
    }

    private var barColor: Color {
        if status.isOverBudget { return Color.moneyStalkerExpense }
        if status.isWarning { return Color.moneyStalkerWarning }
        return Color.moneyStalkerPrimary
    }

    private func money(_ minor: Int64) -> String {
        MoneyText.string(minor: minor, code: status.currencyCode, locale: locale)
    }
}

struct ChartCard<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(Color.moneyStalkerSecondary)
            Text(subtitle).font(.caption).foregroundStyle(Color.moneyStalkerSlate)
            content()
        }
        .moneyStalkerCard(graph: .spark)
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.moneyStalkerPrimary)
                .frame(width: 76, height: 76)
                .background(Color.moneyStalkerPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.moneyStalkerSecondary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.moneyStalkerSlate)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, systemImage: "plus", action: action)
                    .padding(.top, 6)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingView: View {
    var title: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.moneyStalkerSlate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            BacgroundApp()
        }
        .accessibilityLabel(title)
    }
}

struct DateRangePicker: View {
    @Binding var start: Date
    @Binding var end: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("Start", selection: $start, displayedComponents: .date)
            DatePicker("End", selection: $end, in: start..., displayedComponents: .date)
        }
        .font(.subheadline)
    }
}

struct PeriodChipBar: View {
    @Binding var preset: PeriodPreset
    var showsSymbols = false
    var onCustom: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PeriodPreset.allCases) { item in
                    Button {
                        if item == .custom { onCustom() }
                        preset = item
                    } label: {
                        HStack(spacing: 5) {
                            if showsSymbols {
                                Image(systemName: symbol(item))
                                    .font(.caption2.weight(.bold))
                            }
                            Text(shortTitle(item))
                                .font(showsSymbols ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, showsSymbols ? 11 : 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(preset == item ? Color.moneyStalkerOnHero : (showsSymbols ? Color.moneyStalkerSecondary : Color.moneyStalkerSlate))
                        .background(preset == item ? Color.moneyStalkerPrimary : Color.moneyStalkerCard)
                        .clipShape(Capsule())
                        .shadow(color: preset == item && showsSymbols ? Color.moneyStalkerPrimary.opacity(0.28) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(preset == item ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func symbol(_ item: PeriodPreset) -> String {
        switch item {
        case .today: "calendar"
        case .week: "chart.bar.fill"
        case .month: "calendar"
        case .year: "chart.line.uptrend.xyaxis"
        case .custom: "slider.horizontal.3"
        }
    }

    private func shortTitle(_ item: PeriodPreset) -> String {
        switch item {
        case .today: "Today"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .custom: "Custom"
        }
    }
}
