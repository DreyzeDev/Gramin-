import SwiftUI

@main
struct GraminApp: App {
    @StateObject private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if state.isAuthenticated {
                    if state.isLocked {
                        LockView()
                    } else {
                        RootTabView()
                    }
                } else {
                    AuthView()
                }
            }
            .environmentObject(state)
            .environment(\.locale, Locale(identifier: state.appLanguage))
            .preferredColorScheme(state.darkMode ? .dark : .light)
            .task { await state.restoreSession() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { state.lockIfNeeded() }
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView(selection: $state.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Главная", systemImage: "house.fill") }.tag(0)
            NavigationStack { CardsView() }
                .tabItem { Label("Карты", systemImage: "creditcard.fill") }.tag(1)
            NavigationStack { PaymentsView() }
                .tabItem { Label("Платежи", systemImage: "square.grid.2x2.fill") }.tag(2)
            NavigationStack { AnalyticsView() }
                .tabItem { Label("Аналитика", systemImage: "chart.pie.fill") }.tag(3)
            NavigationStack { ProfileView() }
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }.tag(4)
        }
        .tint(.primary)
    }
}
