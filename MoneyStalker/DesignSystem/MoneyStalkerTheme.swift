import SwiftUI
import UIKit

extension Color {
    static var moneyStalkerBackground: Color { ThemeCenter.palette.background }
    static var moneyStalkerCard: Color { ThemeCenter.palette.card }
    static var moneyStalkerPrimary: Color { ThemeCenter.palette.primary }
    static var moneyStalkerSecondary: Color { ThemeCenter.palette.secondary }
    static var moneyStalkerIncome: Color { ThemeCenter.palette.income }
    static var moneyStalkerExpense: Color { ThemeCenter.palette.expense }
    static var moneyStalkerSlate: Color { ThemeCenter.palette.slate }
    static var moneyStalkerBorder: Color { ThemeCenter.palette.border }
    static var moneyStalkerWarning: Color { ThemeCenter.palette.warning }
    static var moneyStalkerHeroStart: Color { ThemeCenter.palette.heroStart }
    static var moneyStalkerHeroEnd: Color { ThemeCenter.palette.heroEnd }
    static var moneyStalkerOnHero: Color { ThemeCenter.palette.onHero }

    init(moneyStalkerHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

enum MoneyStalkerMetrics {
    static let radius: CGFloat = 20
    static let radiusSmall: CGFloat = 14
    static let padding: CGFloat = 16
}

struct CategoryIconGroup: Identifiable {
    var title: String
    var icons: [String]
    var id: String { title }
}

enum MoneyStalkerPalette {
    static let groups: [CategoryIconGroup] = [
        CategoryIconGroup(title: "Finance", icons: ["banknote", "chart.bar", "dollarsign.circle", "building.columns", "bitcoinsign", "creditcard", "checkmark.shield", "doc.text", "wallet.pass", "percent"]),
        CategoryIconGroup(title: "Shopping", icons: ["bag", "cart", "tshirt", "tag", "gift", "crown", "eyeglasses", "applewatch"]),
        CategoryIconGroup(title: "Food", icons: ["fork.knife", "cup.and.saucer", "fish", "carrot", "wineglass", "birthday.cake", "takeoutbag.and.cup.and.straw"]),
        CategoryIconGroup(title: "Life", icons: ["house", "bed.double", "car", "airplane", "heart", "cross.case", "pawprint", "figure.run", "lightbulb", "drop.fill"]),
        CategoryIconGroup(title: "Entertainment", icons: ["gamecontroller", "film", "music.note", "headphones", "ticket", "camera", "tv", "book.closed"]),
        CategoryIconGroup(title: "Others", icons: ["envelope", "mappin", "graduationcap", "briefcase", "wrench.and.screwdriver", "phone", "bus", "leaf", "bolt", "star"])
    ]
    static let icons = groups.flatMap(\.icons)
    static let colors = ["F07167", "E7A0A0", "C4A4A0", "F07A1A", "F5B07A", "C6A227", "B7B04A", "7C9A3C", "2EAE4A", "2EBEA0", "3EC4D0", "1877F2", "2563EB", "7C6CF0", "A855C8", "F472B6"]
}

struct MoneyStalkerCardModifier: ViewModifier {
    var graph: CardGraphKind = .line
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(MoneyStalkerMetrics.padding)
            .background { MoneyStalkerMesh(style: .card, graph: graph) }
            .clipShape(RoundedRectangle(cornerRadius: MoneyStalkerMetrics.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MoneyStalkerMetrics.radius, style: .continuous)
                    .stroke(Color.moneyStalkerBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.05), radius: 12, y: 5)
    }
}

struct AddTransactionBar: ViewModifier {
    @Environment(AppModel.self) private var appModel
    @State private var pulse = 0

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                pulse += 1
                appModel.addTransactionPresented = true
            } label: {
                Label("Add transaction", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .foregroundStyle(Color.moneyStalkerOnHero)
                    .background(Color.moneyStalkerPrimary, in: Capsule())
                    .shadow(color: Color.moneyStalkerPrimary.opacity(0.28), radius: 16, y: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(
                LinearGradient(colors: [Color.moneyStalkerBackground.opacity(0), Color.moneyStalkerBackground], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .bottom)
            )
            .accessibilityLabel("Add transaction")
            .sensoryFeedback(.impact, trigger: pulse)
        }
    }
}

private struct MoneyStalkerActiveTabKey: EnvironmentKey {
    static let defaultValue: AppTab = .home
}

extension EnvironmentValues {
    var moneyStalkerActiveTab: AppTab {
        get { self[MoneyStalkerActiveTabKey.self] }
        set { self[MoneyStalkerActiveTabKey.self] = newValue }
    }
}

private struct TabBarHideOnScroll: ViewModifier {
    var tab: AppTab
    @Environment(AppModel.self) private var appModel
    @Environment(\.moneyStalkerActiveTab) private var activeTab
    @State private var lastTop: CGFloat?
    @State private var quietUntil = Date.distantPast

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, top in
                report(top)
            }
        } else {
            content.background(LegacyTabBarScrollProbe { report($0) })
        }
    }

    private func report(_ top: CGFloat) {
        let previous = lastTop
        lastTop = top
        guard activeTab == tab, let previous else { return }
        guard Date() >= quietUntil else { return }
        let delta = top - previous
        if top <= 2 {
            setHidden(false)
            return
        }
        guard abs(delta) > 14 else { return }
        setHidden(delta > 0)
    }

    private func setHidden(_ hidden: Bool) {
        guard appModel.tabBarHidden != hidden else { return }
        appModel.tabBarHidden = hidden
        quietUntil = Date().addingTimeInterval(0.28)
    }
}

private struct LegacyTabBarScrollProbe: UIViewRepresentable {
    var onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onScroll = { context.coordinator.observe($0) }
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        context.coordinator.onChange = onChange
        uiView.onScroll = { context.coordinator.observe($0) }
        uiView.attach()
    }

    final class Coordinator: NSObject {
        var onChange: (CGFloat) -> Void
        private weak var scroll: UIScrollView?
        private var observation: NSKeyValueObservation?

        init(onChange: @escaping (CGFloat) -> Void) { self.onChange = onChange }

        func observe(_ next: UIScrollView) {
            guard scroll !== next else { return }
            observation?.invalidate()
            scroll = next
            observation = next.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
                let top = scroll.contentOffset.y + scroll.adjustedContentInset.top
                DispatchQueue.main.async { self?.onChange(top) }
            }
        }
    }
}

private final class ProbeView: UIView {
    var onScroll: ((UIScrollView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attach()
    }

    func attach(attempt: Int = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let scroll = self.enclosingScrollView {
                self.onScroll?(scroll)
            } else if attempt < 8 {
                self.attach(attempt: attempt + 1)
            }
        }
    }

    private var enclosingScrollView: UIScrollView? {
        var view: UIView? = superview
        while let current = view {
            if let scroll = current as? UIScrollView { return scroll }
            view = current.superview
        }
        return nil
    }
}

extension View {
    func moneyStalkerHidesTabBar(_ tab: AppTab) -> some View {
        modifier(TabBarHideOnScroll(tab: tab))
    }

    func moneyStalkerCard(graph: CardGraphKind = .line) -> some View { modifier(MoneyStalkerCardModifier(graph: graph)) }

    func moneyStalkerAddBar() -> some View { modifier(AddTransactionBar()) }

    func moneyStalkerScreen() -> some View {
        self
            .background {
                BacgroundApp()
            }
            .scrollDismissesKeyboard(.interactively)
    }

    func moneyStalkerConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        role: ButtonRole = .destructive,
        action: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button(confirmTitle, role: role, action: action)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

extension AppearanceMode {
    var preferredScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
