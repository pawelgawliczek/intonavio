#if DEBUG
import SwiftUI

/// Debug-only developer tools for testing the full workflow.
struct DeveloperView: View {
    @Environment(AppState.self) private var appState
    @State private var songs: [SongResponse] = []
    @State private var isLoadingSongs = false
    @State private var errorText: String?
    @State private var showTokens = false
    @State private var statusMessage: String?
    @State private var addSongURL = ""
    @State private var isAddingSong = false

    @State private var isPitchDebugEnabled = false
    @State private var isPitchRecording = false

    var body: some View {
        List {
            apiSection
            authSection
            pitchDebugSection
            addSongSection
            songsSection
            actionsSection
        }
        .navigationTitle("Developer")
        .onAppear { loadSongs() }
    }
}

// MARK: - Sections

private extension DeveloperView {
    var apiSection: some View {
        Section("API") {
            LabeledContent("Base URL") {
                Text(apiBaseURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Has Access Token") {
                tokenIndicator(TokenManager.shared.accessToken != nil)
            }
            LabeledContent("Has Refresh Token") {
                tokenIndicator(TokenManager.shared.refreshToken != nil)
            }
            if let msg = statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    var authSection: some View {
        Section("Auth") {
            LabeledContent("Authenticated") {
                tokenIndicator(appState.isAuthenticated)
            }
            if let user = appState.currentUser {
                LabeledContent("User", value: user.displayName)
                LabeledContent("Email", value: user.email ?? "—")
                LabeledContent("ID") {
                    Text(user.id)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Button(showTokens ? "Hide Tokens" : "Show Tokens") {
                showTokens.toggle()
            }
            if showTokens {
                tokenRow("Access", token: TokenManager.shared.accessToken)
                tokenRow("Refresh", token: TokenManager.shared.refreshToken)
            }
        }
    }

    var addSongSection: some View {
        Section {
            TextField("YouTube URL", text: $addSongURL)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button {
                addSong()
            } label: {
                HStack {
                    if isAddingSong {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isAddingSong ? "Adding..." : "Add Song to Library")
                }
            }
            .disabled(addSongURL.isEmpty || isAddingSong)
        } header: {
            Text("Quick Add Song")
        } footer: {
            Text("Songs are per-user. Paste a YouTube URL to add it to your library.")
        }
    }

    var songsSection: some View {
        Section {
            songContent
        } header: {
            HStack {
                Text("My Library (\(songs.count))")
                Spacer()
                Button("Reload") { loadSongs() }
                    .font(.caption)
            }
        } footer: {
            Text("Tap a READY song to open the practice view.")
        }
    }

    var pitchDebugSection: some View {
        Section("Pitch Debug") {
            Toggle("Debug Overlay", isOn: $isPitchDebugEnabled)
            Toggle("Record Pitch Data", isOn: $isPitchRecording)
            Button("Export Recording") {
                statusMessage = "Pitch recording export not active"
            }
            .disabled(!isPitchRecording)
        }
    }

    var actionsSection: some View {
        Section("Quick Actions") {
            Button("Force Token Refresh") { forceRefresh() }
            Button("Clear Keychain & Sign Out") { appState.signOut() }
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Subviews

private extension DeveloperView {
    func tokenIndicator(_ hasToken: Bool) -> some View {
        Image(systemName: hasToken ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(hasToken ? .green : .red)
    }

    func tokenRow(_ label: String, token: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.bold())
            if let token {
                Text(String(token.prefix(40)) + "...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("nil").font(.caption2).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    var songContent: some View {
        if isLoadingSongs {
            ProgressView("Loading songs...")
        } else if let err = errorText {
            VStack(alignment: .leading, spacing: 4) {
                Text("Error:").font(.caption.bold()).foregroundStyle(.red)
                Text(err).foregroundStyle(.red).font(.caption).textSelection(.enabled)
            }
        } else if songs.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your library is empty").foregroundStyle(.secondary)
                Text("Use Quick Add Song above to add a YouTube URL.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        } else {
            ForEach(songs) { song in
                NavigationLink {
                    SongPracticeView(songId: song.id, videoId: song.videoId, stems: song.stems, hasPitchData: song.pitchData != nil)
                } label: {
                    DevSongRow(song: song)
                }
                .disabled(song.status != .ready)
            }
        }
    }
}

private extension DeveloperView {
    var apiBaseURL: String {
        let bundleURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        if let url = bundleURL, !url.isEmpty, !url.contains("$(") {
            return url
        }
        return "http://localhost:3000/v1"
    }

    func loadSongs() {
        Task { @MainActor in
            isLoadingSongs = true
            errorText = nil
            do {
                let response = try await appState.apiClient.listSongs(page: 1, limit: 100)
                songs = response.data
                statusMessage = "Loaded \(response.data.count) songs (total: \(response.meta.total))"
            } catch {
                errorText = describeError(error)
            }
            isLoadingSongs = false
        }
    }

    func addSong() {
        let url = addSongURL.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        Task { @MainActor in
            isAddingSong = true
            statusMessage = nil
            do {
                let song = try await appState.apiClient.createSong(
                    CreateSongRequest(youtubeUrl: url)
                )
                statusMessage = "Added: \(song.title) (\(song.status.rawValue))"
                addSongURL = ""
                loadSongs()
            } catch {
                statusMessage = "Add failed: \(describeError(error))"
            }
            isAddingSong = false
        }
    }

    func forceRefresh() {
        Task { @MainActor in
            guard let token = TokenManager.shared.refreshToken else {
                statusMessage = "No refresh token in Keychain"
                return
            }
            do {
                let response = try await appState.apiClient.refreshToken(
                    RefreshRequest(refreshToken: token)
                )
                TokenManager.shared.storeTokens(
                    access: response.accessToken,
                    refresh: response.refreshToken
                )
                appState.signIn(user: response.user)
                statusMessage = "Token refreshed for \(response.user.displayName)"
            } catch {
                statusMessage = "Refresh failed: \(describeError(error))"
            }
        }
    }

    func describeError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return "[\(apiError.statusCode)] \(apiError.message)"
        }
        if let networkError = error as? NetworkError {
            return "Network: \(networkError)"
        }
        return error.localizedDescription
    }
}

/// Extracted row view for developer song list.
struct DevSongRow: View {
    let song: SongResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.title).font(.body).lineLimit(2)
            HStack(spacing: 8) {
                statusBadge
                Text(song.videoId).font(.caption2).foregroundStyle(.tertiary)
            }
            if !song.stems.isEmpty {
                let types = song.stems.map(\.type.rawValue).joined(separator: ", ")
                Text("\(song.stems.count) stems: \(types)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        Text(song.status.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch song.status {
        case .ready: return .green
        case .failed: return .red
        case .queued, .downloading, .splitting, .analyzing: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperView()
    }
    .environment(AppState())
}
#endif
