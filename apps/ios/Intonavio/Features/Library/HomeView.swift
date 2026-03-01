import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LibraryViewModel()

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
            }
            .padding(.vertical)
        }
        .background(Color.intonavioBackground.ignoresSafeArea())
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
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
                NavigationLink(value: song.id) {
                    SongGridItemView(song: song)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .navigationDestination(for: String.self) { songId in
            if let song = viewModel.songs.first(where: { $0.id == songId }) {
                SongPracticeView(songId: song.id, videoId: song.videoId, stems: song.stems, hasPitchData: song.pitchData != nil)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(Color.intonavioIce)
            Text("No songs yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tap + to add a YouTube song")
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

    var songs: [SongResponse] {
        viewModel.songs
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
