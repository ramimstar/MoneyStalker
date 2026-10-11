import SwiftUI
import SwiftData

@main
struct MoneyStalkerApp: App {
    @State private var appModel = AppModel.live

    var body: some Scene {
        WindowGroup {
            ThemeHost {
                RootView()
            }
            .environment(appModel)
            .modelContainer(appModel.container)
            .preferredColorScheme(appModel.settings.appearance.preferredScheme)
            .environment(\.locale, appModel.settings.formattingLocale)
        }
    }
}

struct ThemeHost<Content: View>: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let _ = ThemeCenter.apply(appModel.settings.theme, colorScheme)
        content()
            .id("\(appModel.settings.theme.rawValue)-\(colorScheme == .dark ? "dark" : "light")")
            .tint(Color.moneyStalkerPrimary)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appModel.isLocked {
                LockView()
            } else if !appModel.settings.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .background {
            BacgroundApp()
        }
        .task { await bootstrap() }
        .onAppear { SoftwareKeyboard.preferOnScreenKeypad() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            SoftwareKeyboard.preferOnScreenKeypad()
            guard !appModel.isLocked, appModel.settings.hasCompletedOnboarding else { return }
            Task { await NotificationScheduler.reconcile(context: context, settings: appModel.settings) }
        }
        .alert("Money Stalker", isPresented: errorPresented) {
            Button("OK", role: .cancel) { appModel.bootstrapError = nil }
        } message: {
            Text(appModel.bootstrapError ?? "")
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { appModel.bootstrapError != nil }, set: { if !$0 { appModel.bootstrapError = nil } })
    }

    private func bootstrap() async {
        do {
            try BackupService.recoverIfNeeded(context: context, settings: appModel.settings, directory: BackupService.supportDirectory())
            try SeedService.seedIfNeeded(context: context)
            try RecurringProcessor.process(context: context, now: .now, calendar: appModel.settings.calendar)
            await NotificationScheduler.reconcile(context: context, settings: appModel.settings)
        } catch {
            appModel.bootstrapError = error.localizedDescription
        }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @State private var addPulse = 0

    var body: some View {
        @Bindable var appModel = appModel
        ZStack {
            DashboardView()
                .opacity(appModel.selectedTab == .home ? 1 : 0)
                .allowsHitTesting(appModel.selectedTab == .home)
                .accessibilityHidden(appModel.selectedTab != .home)
            TransactionListView()
                .opacity(appModel.selectedTab == .transactions ? 1 : 0)
                .allowsHitTesting(appModel.selectedTab == .transactions)
                .accessibilityHidden(appModel.selectedTab != .transactions)
            BudgetsView()
                .opacity(appModel.selectedTab == .budgets ? 1 : 0)
                .allowsHitTesting(appModel.selectedTab == .budgets)
                .accessibilityHidden(appModel.selectedTab != .budgets)
            SettingsView()
                .opacity(appModel.selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(appModel.selectedTab == .settings)
                .accessibilityHidden(appModel.selectedTab != .settings)
        }
        .environment(\.moneyStalkerActiveTab, appModel.selectedTab)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !appModel.tabBarHidden {
                tabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: appModel.tabBarHidden)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: appModel.selectedTab) { _, _ in
            appModel.tabBarHidden = false
        }
        .sheet(isPresented: $appModel.addTransactionPresented) {
            TransactionEditorView(mode: .create)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Home", "house.fill", .home)
            tabButton("Activity", "list.bullet.rectangle.fill", .transactions)
            Button {
                addPulse += 1
                appModel.addTransactionPresented = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.moneyStalkerOnHero)
                        .frame(width: 46, height: 46)
                        .background(Color.moneyStalkerPrimary, in: Circle())
                    Text("Add")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.moneyStalkerPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add transaction")
            .sensoryFeedback(.impact, trigger: addPulse)
            tabButton("Budgets", "chart.pie.fill", .budgets)
            tabButton("Settings", "gearshape.fill", .settings)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color.moneyStalkerCard)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.moneyStalkerBorder).frame(height: 1)
        }
    }

    private func tabButton(_ title: String, _ symbol: String, _ value: AppTab) -> some View {
        Button {
            appModel.selectedTab = value
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(height: 46)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(appModel.selectedTab == value ? Color.moneyStalkerPrimary : Color.moneyStalkerSlate)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(appModel.selectedTab == value ? .isSelected : [])
    }
}

#Preview("Money Stalker") {
    MoneyStalkerPreview.host { MainTabView() }
}
