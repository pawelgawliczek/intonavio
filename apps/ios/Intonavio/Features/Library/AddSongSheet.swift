import SwiftUI

struct AddSongSheet: View {
    @Bindable var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                instructions
                urlInput
                errorText
                submitButton
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .background(Color.intonavioBackground.ignoresSafeArea())
            .navigationTitle("Add Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Subviews

private extension AddSongSheet {
    var instructions: some View {
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
    var errorText: some View {
        if let error = viewModel.addSongError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    var submitButton: some View {
        Button(action: viewModel.addSong) {
            if viewModel.isAddingSong {
                ProgressView()
            } else {
                Text("Add Song")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(viewModel.isAddingSong)
    }
}

#Preview {
    AddSongSheet(viewModel: LibraryViewModel(apiClient: MockAPIClient()))
}
