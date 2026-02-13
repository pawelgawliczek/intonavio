import SwiftUI

/// Global app state shared across the entire view hierarchy.
/// Uses @Observable (iOS 17+) per code quality standards.
@Observable
final class AppState {
    var isAuthenticated = false
    var selectedTab: Tab = .library
    var currentUser: AuthUser?

    enum Tab: Int {
        case library = 0
        case sessions = 1
        case settings = 2
    }

    private let tokenManager: TokenManager
    let apiClient: any APIClientProtocol

    init(
        tokenManager: TokenManager = .shared,
        apiClient: any APIClientProtocol = APIClient()
    ) {
        self.tokenManager = tokenManager
        self.apiClient = apiClient
    }

    /// Check Keychain for tokens on launch and verify validity.
    func restoreAuth() {
        guard tokenManager.hasValidTokens else {
            isAuthenticated = false
            return
        }

        isAuthenticated = true

        Task { @MainActor in
            await refreshTokenInBackground()
        }
    }

    func signIn(user: AuthUser) {
        currentUser = user
        isAuthenticated = true
    }

    func signOut() {
        tokenManager.clearTokens()
        isAuthenticated = false
        currentUser = nil
        selectedTab = .library
        AppLogger.auth.info("User signed out")
    }

    @MainActor
    func deleteAccount() async throws {
        try await apiClient.deleteAccount()
        tokenManager.clearTokens()
        isAuthenticated = false
        currentUser = nil
        selectedTab = .library
        AppLogger.auth.info("Account deleted")
    }
}

// MARK: - Private

private extension AppState {
    @MainActor
    func refreshTokenInBackground() async {
        guard let refreshTokenValue = tokenManager.refreshToken else {
            return
        }

        do {
            let response = try await apiClient.refreshToken(
                RefreshRequest(refreshToken: refreshTokenValue)
            )
            tokenManager.storeTokens(
                access: response.accessToken,
                refresh: response.refreshToken
            )
            currentUser = response.user
            AppLogger.auth.info("Token refreshed successfully")
        } catch {
            AppLogger.auth.warning("Token refresh failed: \(error.localizedDescription)")
            tokenManager.clearTokens()
            isAuthenticated = false
        }
    }
}
