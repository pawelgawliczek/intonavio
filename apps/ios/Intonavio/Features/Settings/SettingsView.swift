import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @State private var pitchCacheCleared = false
    @AppStorage("appTheme") private var themeRaw = AppTheme.system.rawValue

    var body: some View {
        List {
            accountSection
            audioInputSection
            guideToneSection
            themeSection
            dataSection
            aboutSection
            #if DEBUG
            developerSection
            #endif
            dangerSection
        }
        .navigationTitle("Settings")
        .onAppear { viewModel.loadAudioInputs() }
        .alert("Error", isPresented: hasError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Delete Account", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your account and all data. This cannot be undone.")
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Sections

private extension SettingsView {
    var accountSection: some View {
        Section("Account") {
            NavigationLink {
                ProfileView()
            } label: {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(appState.currentUser?.displayName ?? "User")
                            .font(.body)
                        if let email = appState.currentUser?.email {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button("Sign Out") {
                appState.signOut()
            }
            .foregroundStyle(.red)
        }
    }

    var audioInputSection: some View {
        Section("Audio Input") {
            #if os(iOS)
            ForEach(viewModel.availableInputs, id: \.uid) { port in
                Button {
                    viewModel.selectInput(port)
                } label: {
                    HStack {
                        Text(port.portName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if port.uid == viewModel.selectedInputUID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            if viewModel.availableInputs.isEmpty {
                Text("No audio inputs available")
                    .foregroundStyle(.secondary)
            }
            #else
            ForEach(viewModel.availableDevices, id: \.uniqueID) { device in
                Button {
                    viewModel.selectDevice(device)
                } label: {
                    HStack {
                        Text(device.localizedName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if device.uniqueID == viewModel.selectedInputUID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            if viewModel.availableDevices.isEmpty {
                Text("No audio inputs available")
                    .foregroundStyle(.secondary)
            }
            #endif
        }
    }

    var guideToneSection: some View {
        Section("Guide Tone") {
            NavigationLink {
                GuideToneSettingsView()
            } label: {
                HStack {
                    Text("Instrument")
                    Spacer()
                    Text(currentGuideToneLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var currentGuideToneLabel: String {
        let stored = UserDefaults.standard.integer(forKey: "guideToneInstrument")
        let instrument = GuideToneInstrument(rawValue: stored) ?? .acousticGrandPiano
        return instrument.label
    }

    var themeSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                    Text(theme.label).tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    var dataSection: some View {
        Section {
            Button {
                PitchDataDownloader.clearAllCache()
                pitchCacheCleared = true
            } label: {
                HStack {
                    Text("Clear Pitch Cache")
                    Spacer()
                    if pitchCacheCleared {
                        Text("Cleared")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(pitchCacheCleared)
        } header: {
            Text("Data")
        } footer: {
            Text("Re-downloads pitch data from the server next time you practice a song.")
        }
    }

    var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        }
    }

    #if DEBUG
    var developerSection: some View {
        Section("Developer") {
            NavigationLink {
                DeveloperView()
            } label: {
                Label("Developer Tools", systemImage: "hammer")
            }
        }
    }
    #endif

    var dangerSection: some View {
        Section {
            Button("Delete Account") {
                viewModel.showDeleteConfirmation = true
            }
            .foregroundStyle(.red)
        } footer: {
            Text("Permanently deletes your account and all associated data.")
        }
    }
}

// MARK: - Actions

private extension SettingsView {
    @MainActor
    func deleteAccount() async {
        viewModel.isDeleting = true
        do {
            try await appState.deleteAccount()
        } catch {
            viewModel.errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }
        viewModel.isDeleting = false
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
}
