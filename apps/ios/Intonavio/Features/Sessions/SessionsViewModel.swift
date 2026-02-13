import Foundation

/// Manages session history: fetch, paginate, save new sessions.
@Observable
final class SessionsViewModel {
    var sessions: [SessionResponse] = []
    var isLoading = false
    var errorMessage: String?

    private let apiClient: any APIClientProtocol
    private var currentPage = 1
    private var totalPages = 1
    var hasMorePages: Bool { currentPage < totalPages }

    init(apiClient: any APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch

    func fetchSessions() {
        Task { @MainActor in
            await loadSessions(page: 1)
        }
    }

    func loadMore() {
        guard hasMorePages, !isLoading else { return }
        Task { @MainActor in
            await loadSessions(page: currentPage + 1)
        }
    }

    @MainActor
    func loadSessions(page: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiClient.listSessions(page: page, limit: 20)
            if page == 1 {
                sessions = response.data
            } else {
                sessions.append(contentsOf: response.data)
            }
            currentPage = response.meta.page
            totalPages = response.meta.totalPages
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            AppLogger.sessions.error("Failed to load sessions: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Save Session

    func saveSession(_ request: CreateSessionRequest) {
        Task { @MainActor in
            do {
                let session = try await apiClient.createSession(request)
                sessions.insert(session, at: 0)
                AppLogger.sessions.info("Session saved: \(session.id)")
            } catch {
                AppLogger.sessions.error(
                    "Failed to save session: \(error.localizedDescription)"
                )
            }
        }
    }
}
