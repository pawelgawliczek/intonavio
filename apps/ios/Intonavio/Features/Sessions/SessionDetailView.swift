import SwiftUI

struct SessionDetailView: View {
    let sessionId: String

    @State private var detail: SessionDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient: any APIClientProtocol

    init(
        sessionId: String,
        apiClient: any APIClientProtocol = APIClient()
    ) {
        self.sessionId = sessionId
        self.apiClient = apiClient
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let detail {
                sessionContent(detail)
            } else if let error = errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
    }
}

// MARK: - Content

private extension SessionDetailView {
    func sessionContent(_ session: SessionDetailResponse) -> some View {
        List {
            Section("Score") {
                HStack {
                    Text("Overall")
                    Spacer()
                    Text(String(format: "%.1f%%", session.overallScore))
                        .font(.title2.bold())
                }
            }

            Section("Details") {
                detailRow("Duration", "\(session.duration)s")
                detailRow("Speed", String(format: "%.2gx", session.speed))
                if let start = session.loopStart, let end = session.loopEnd {
                    detailRow("Loop", "\(formatTime(start)) - \(formatTime(end))")
                }
            }

            Section("Pitch Graph") {
                Text("Pitch visualization coming in Phase 5")
                    .foregroundStyle(.secondary)
                Text("\(session.pitchLog.count) pitch log entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Loading

private extension SessionDetailView {
    @MainActor
    func loadDetail() async {
        isLoading = true
        do {
            detail = try await apiClient.getSession(id: sessionId)
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionId: "sess1", apiClient: MockAPIClient())
    }
}
