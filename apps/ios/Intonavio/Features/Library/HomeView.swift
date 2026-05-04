import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LibraryViewModel()
    private var network: NetworkMonitor { NetworkMonitor.shared }

    #if os(iOS)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    #else
    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 12)
    ]
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                songSection
                Divider()
                exerciseSection
                Divider()
                recordingsSection
            }
            .padding(.vertical)
        }
        .background(Color.intonavioBackground.ignoresSafeArea())
        .navigationTitle("Library")
        .toolbar {
            if !network.isConnected {
                ToolbarItem(placement: .navigationBarLeading) {
                    Label("Offline", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(Color.intonavioTextSecondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!network.isConnected)
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddSongSheet(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.loadSongs()
        }
        .onAppear {
            if viewModel.songs.isEmpty, appState.isAuthenticated {
                viewModel.fetchSongs()
            }
            viewModel.refreshEditedSongIds()
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated, viewModel.songs.isEmpty {
                viewModel.fetchSongs()
            }
        }
    }
}

// MARK: - Subviews

private extension HomeView {
    var songSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Songs")
                    .font(.title2.bold())
                Spacer()
                archiveToggle
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding(.horizontal)

            if songs.isEmpty, !viewModel.isLoading {
                emptyState
            } else {
                songGrid
            }
        }
    }

    var songGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(songs) { song in
                let isAvailableOffline = isSongAvailableOffline(song)
                if !network.isConnected && !isAvailableOffline {
                    SongGridItemView(
                        song: song,
                        isOfflineUnavailable: true,
                        isEdited: viewModel.editedSongIds.contains(song.id)
                    )
                    .contextMenu {
                        songArchiveButton(song)
                    }
                } else {
                    NavigationLink(value: song.id) {
                        SongGridItemView(
                            song: song,
                            isEdited: viewModel.editedSongIds.contains(song.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        songArchiveButton(song)
                    }
                }
            }
        }
        .padding(.horizontal)
        .navigationDestination(for: String.self) { songId in
            if let song = viewModel.songs.first(where: { $0.id == songId }) {
                let isOffline = !network.isConnected
                SongPracticeView(
                    songId: song.id,
                    videoId: song.videoId,
                    stems: song.stems,
                    hasPitchData: song.pitchData != nil,
                    isOffline: isOffline,
                    songTitle: song.title,
                    songArtist: song.artist,
                    songDuration: song.duration,
                    variants: song.variants,
                    activeVariantId: song.activeVariantId
                )
            }
        }
    }

    func isSongAvailableOffline(_ song: SongResponse) -> Bool {
        let variantId = song.activeVariant?.id
        return song.status == .ready
            && StemDownloader.isCached(songId: song.id, stems: song.stems, variantId: variantId)
            && PitchDataDownloader.isCached(songId: song.id, variantId: variantId)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.isShowingArchive ? "archivebox" : "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(Color.intonavioIce)
            Text(viewModel.isShowingArchive ? "Archive is empty" : "No songs yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.title2.bold())
                .padding(.horizontal)

            ExerciseSectionView()
        }
    }

    var recordingsSection: some View {
        RecordingsSectionView()
    }

    var songs: [SongResponse] {
        viewModel.isShowingArchive ? viewModel.archivedSongs : viewModel.activeSongs
    }

    var archiveToggle: some View {
        Button {
            viewModel.isShowingArchive.toggle()
        } label: {
            Label(
                viewModel.isShowingArchive ? "Songs" : "Archive",
                systemImage: viewModel.isShowingArchive ? "music.note.list" : "archivebox"
            )
            .labelStyle(.iconOnly)
        }
        .foregroundStyle(Color.intonavioIce)
        .accessibilityLabel(viewModel.isShowingArchive ? "Show my songs" : "Show archive")
    }

    var emptyStateMessage: String {
        if viewModel.isShowingArchive {
            return "Archived songs stay here until you restore them"
        }
        return "Tap + to add a YouTube song"
    }

    @ViewBuilder
    func songArchiveButton(_ song: SongResponse) -> some View {
        if viewModel.archivedSongIds.contains(song.id) {
            Button {
                viewModel.unarchiveSong(song)
            } label: {
                Label("Unarchive", systemImage: "tray.and.arrow.up")
            }
        } else {
            Button {
                viewModel.archiveSong(song)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
