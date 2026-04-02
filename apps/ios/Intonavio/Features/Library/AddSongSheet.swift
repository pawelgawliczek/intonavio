import SwiftUI

struct AddSongSheet: View {
    @Bindable var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                    .padding(.top, 12)

                if viewModel.addSongMode == .search {
                    searchContent
                } else {
                    urlContent
                }
            }
            .background(Color.intonavioBackground.ignoresSafeArea())
            .navigationTitle("Add Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $viewModel.selectedSearchResult) { result in
                SongConfirmationView(
                    result: result,
                    isAdding: viewModel.addingVideoId == result.videoId,
                    error: viewModel.searchError
                ) {
                    viewModel.addFromSearch(result)
                }
            }
        }
    }
}

// MARK: - Mode Picker

private extension AddSongSheet {
    var modePicker: some View {
        Picker("Mode", selection: $viewModel.addSongMode) {
            Label("Search", systemImage: "magnifyingglass")
                .tag(AddSongMode.search)
            Label("Paste URL", systemImage: "link")
                .tag(AddSongMode.url)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }
}

// MARK: - Search Mode

private extension AddSongSheet {
    var searchContent: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 24)
                .padding(.top, 16)

            if viewModel.isSearching {
                Spacer()
                ProgressView()
                    .tint(.intonavioIce)
                Spacer()
            } else if let error = viewModel.searchError,
                      viewModel.selectedSearchResult == nil {
                Spacer()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                Spacer()
            } else if viewModel.searchResults.isEmpty, !viewModel.searchQuery.isEmpty {
                Spacer()
                Text("No results found")
                    .font(.subheadline)
                    .foregroundStyle(Color.intonavioTextSecondary)
                Spacer()
            } else {
                searchResultsList
            }
        }
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.intonavioTextSecondary)
            TextField("Search songs...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { viewModel.performSearch() }
        }
        .padding(12)
        .background(Color.intonavioSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { result in
                    SearchResultRow(result: result) {
                        viewModel.selectedSearchResult = result
                    }
                    Divider()
                        .overlay(Color.intonavioSurface)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - URL Mode

private extension AddSongSheet {
    var urlContent: some View {
        VStack(spacing: 20) {
            urlInstructions
            urlInput
            urlErrorText
            urlSubmitButton
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    var urlInstructions: some View {
        VStack(spacing: 8) {
            Image(systemName: "link.badge.plus")
                .font(.title)
                .foregroundStyle(LinearGradient.intonavio)
            Text("Paste a YouTube URL")
                .font(.headline)
                .foregroundStyle(.white)
            Text("The song will be processed for stem separation and pitch analysis.")
                .font(.caption)
                .foregroundStyle(Color.intonavioTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    var urlInput: some View {
        TextField("https://youtube.com/watch?v=...", text: $viewModel.addSongURL)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }

    @ViewBuilder
    var urlErrorText: some View {
        if let error = viewModel.addSongError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    var urlSubmitButton: some View {
        Button(action: viewModel.addSong) {
            if viewModel.isAddingSong {
                ProgressView()
            } else {
                Text("Check Song")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(viewModel.isAddingSong)
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let result: YouTubeSearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                thumbnail
                details
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        AsyncImage(url: URL(string: result.thumbnailUrl)) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Color.intonavioSurface
        }
        .frame(width: 80, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(result.title)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(result.artist)
                    .font(.caption)
                    .foregroundStyle(Color.intonavioTextSecondary)
                    .lineLimit(1)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(Color.intonavioTextSecondary)

                Text(result.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(Color.intonavioTextSecondary)

                if result.hasLyrics {
                    lyricsBadge
                }
            }
        }
    }

    private var lyricsBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "music.note")
                .font(.system(size: 8))
            Text("Lyrics")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(Color.intonavioMagenta)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.intonavioMagenta.opacity(0.15))
        )
    }
}

// MARK: - Song Confirmation View

struct SongConfirmationView: View {
    let result: YouTubeSearchResult
    let isAdding: Bool
    let error: String?
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            largeThumbnail
            songDetails
            lyricsStatus
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
            addButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .background(Color.intonavioBackground.ignoresSafeArea())
        .navigationTitle("Confirm Song")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var largeThumbnail: some View {
        AsyncImage(url: URL(string: result.thumbnailUrl)) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Color.intonavioSurface
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var songDetails: some View {
        VStack(spacing: 6) {
            Text(result.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(result.artist)
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)

            Text(result.formattedDuration)
                .font(.caption)
                .foregroundStyle(Color.intonavioTextSecondary)
        }
    }

    private var lyricsStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: result.hasLyrics ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(result.hasLyrics ? .green : Color.intonavioTextSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.hasLyrics ? "Synced Lyrics Available" : "No Synced Lyrics Found")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Text(result.hasLyrics
                     ? "Lyrics will be shown during practice."
                     : "You can still practice with pitch detection only.")
                    .font(.caption)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.intonavioSurface)
        )
    }

    private var addButton: some View {
        Button(action: onConfirm) {
            if isAdding {
                ProgressView()
            } else {
                Text("Add Song")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isAdding)
        .padding(.bottom, 16)
    }
}

#Preview {
    AddSongSheet(viewModel: LibraryViewModel(apiClient: MockAPIClient()))
}
