import SwiftUI

/// Root view with tab navigation (iOS) or sidebar navigation (macOS) and auth gate.
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Group {
            #if os(iOS)
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
            #else
            NavigationSplitView {
                List(selection: $state.selectedTab) {
                    Label("Library", systemImage: "music.note.list")
                        .tag(AppState.Tab.library)
                    Label("Sessions", systemImage: "clock.arrow.circlepath")
                        .tag(AppState.Tab.sessions)
                    Label("Settings", systemImage: "gearshape")
                        .tag(AppState.Tab.settings)
                }
                .navigationTitle("Intonavio")
            } detail: {
                NavigationStack {
                    switch state.selectedTab {
                    case .library:
                        HomeView()
                    case .sessions:
                        SessionHistoryView()
                    case .settings:
                        SettingsView()
                    }
                }
            }
            .frame(minWidth: 900, minHeight: 600)
            .sheet(isPresented: isNotAuthenticated) {
                SignInView()
                    .environment(appState)
                    .frame(width: 400, height: 500)
            }
            #endif
        }
        .tint(Color.intonavioIce)
        .background(Color.intonavioBackground)
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
