import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @State private var pitchCacheCleared = false
    @AppStorage("difficultyLevel") private var difficultyRaw = DifficultyLevel.beginner.rawValue

    var body: some View {
        List {
            accountSection
            audioInputSection
            guideToneSection
            difficultySection
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

    var difficultySection: some View {
        Section {
            Picker("Difficulty", selection: $difficultyRaw) {
                ForEach(DifficultyLevel.allCases, id: \.rawValue) { level in
                    Text(level.label).tag(level.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if let selected = DifficultyLevel(rawValue: difficultyRaw) {
                HStack(spacing: 8) {
                    Image(systemName: selected.icon)
                        .foregroundStyle(.secondary)
                    Text(selected.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DifficultyZonePreview(difficulty: selected)
            }
        } header: {
            Text("Difficulty")
        } footer: {
            Text("Controls how precisely you need to match the pitch. Beginner has wider tolerance zones.")
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
                            .foregroundStyle(Color.intonavioTextSecondary)
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
                    .foregroundStyle(Color.intonavioTextSecondary)
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

// MARK: - Difficulty Zone Preview

/// Horizontal bar showing relative zone widths for a difficulty level.
/// Uses the widest level (beginner) as the full-width reference so
/// bars visibly shrink for harder difficulties.
private struct DifficultyZonePreview: View {
    let difficulty: DifficultyLevel

    /// Fixed reference so all levels are compared against the same max.
    private let maxCents = DifficultyLevel.beginner.fairCents

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                // Fair
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: width * CGFloat(difficulty.fairCents / maxCents))

                // Good
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow.opacity(0.4))
                    .frame(width: width * CGFloat(difficulty.goodCents / maxCents))

                // Excellent
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.5))
                    .frame(width: width * CGFloat(difficulty.excellentCents / maxCents))
            }
        }
        .frame(height: 12)

        HStack {
            Label("Perfect", systemImage: "circle.fill")
                .foregroundStyle(.green)
            Spacer()
            Label("Good", systemImage: "circle.fill")
                .foregroundStyle(.yellow)
            Spacer()
            Label("OK", systemImage: "circle.fill")
                .foregroundStyle(.orange)
        }
        .font(.caption2)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
}
