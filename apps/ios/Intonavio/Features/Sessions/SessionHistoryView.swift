import SwiftUI

struct SessionHistoryView: View {
    @State private var viewModel = SessionsViewModel()

    var body: some View {
        Group {
            if viewModel.sessions.isEmpty, !viewModel.isLoading {
                emptyState
            } else {
                sessionList
            }
        }
        .navigationTitle("Sessions")
        .refreshable {
            await viewModel.loadSessions(page: 1)
        }
        .onAppear {
            if viewModel.sessions.isEmpty {
                viewModel.fetchSessions()
            }
        }
    }
}

// MARK: - Subviews

private extension SessionHistoryView {
    var sessionList: some View {
        List {
            ForEach(viewModel.sessions) { session in
                NavigationLink(value: session.id) {
                    SessionRowView(session: session)
                }
            }

            if viewModel.hasMorePages {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear { viewModel.loadMore() }
            }
        }
        .navigationDestination(for: String.self) { sessionId in
            SessionDetailView(sessionId: sessionId)
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(Color.intonavioTextSecondary)
            Text("No sessions yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Practice a song to see your history here")
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        SessionHistoryView()
    }
}
