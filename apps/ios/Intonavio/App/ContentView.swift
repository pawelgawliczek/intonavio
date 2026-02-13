import SwiftUI

/// Root view with 3-tab navigation and auth gate.
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        TabView(selection: $state.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Library", systemImage: "music.note.list")
            }
            .tag(AppState.Tab.library)

            NavigationStack {
                SessionHistoryView()
            }
            .tabItem {
                Label("Sessions", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppState.Tab.sessions)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppState.Tab.settings)
        }
        .fullScreenCover(isPresented: isNotAuthenticated) {
            SignInView()
                .environment(appState)
        }
        .onAppear {
            appState.restoreAuth()
            WebViewPrewarmer.shared.warmUp()
        }
    }

    private var isNotAuthenticated: Binding<Bool> {
        Binding(
            get: { !appState.isAuthenticated },
            set: { appState.isAuthenticated = !$0 }
        )
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
