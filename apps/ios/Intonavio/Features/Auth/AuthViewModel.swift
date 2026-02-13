import AuthenticationServices
import Foundation

/// Manages authentication flows: Apple Sign In, email login/register.
@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var displayName = ""
    var isLoading = false
    var errorMessage: String?
    var showSignUp = false

    private let apiClient: any APIClientProtocol
    private let tokenManager: TokenManager
    private var onAuthenticated: ((AuthUser) -> Void)?

    init(
        apiClient: any APIClientProtocol = APIClient(),
        tokenManager: TokenManager = .shared,
        onAuthenticated: ((AuthUser) -> Void)? = nil
    ) {
        self.apiClient = apiClient
        self.tokenManager = tokenManager
        self.onAuthenticated = onAuthenticated
    }

    func setOnAuthenticated(_ handler: @escaping (AuthUser) -> Void) {
        onAuthenticated = handler
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  let codeData = credential.authorizationCode,
                  let authCode = String(data: codeData, encoding: .utf8) else {
                errorMessage = "Failed to get Apple credentials"
                return
            }

            let fullName = buildFullName(from: credential.fullName)

            Task { @MainActor in
                await performAppleSignIn(
                    identityToken: identityToken,
                    authorizationCode: authCode,
                    fullName: fullName
                )
            }

        case .failure(let error):
            let nsError = error as NSError
            if nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            if nsError.code == ASAuthorizationError.unknown.rawValue {
                errorMessage = "Apple Sign In is not available. "
                    + "Check that you are signed in to your Apple ID in Settings."
                return
            }
            errorMessage = "Apple Sign In failed. Please try again."
        }
    }

    // MARK: - Email Auth

    func login() {
        guard validateLoginFields() else { return }
        Task { @MainActor in
            await performLogin()
        }
    }

    func register() {
        guard validateRegisterFields() else { return }
        Task { @MainActor in
            await performRegister()
        }
    }
}

// MARK: - Private Methods

private extension AuthViewModel {
    @MainActor
    func performAppleSignIn(
        identityToken: String,
        authorizationCode: String,
        fullName: String?
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiClient.appleSignIn(
                AppleSignInRequest(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    fullName: fullName
                )
            )
            handleAuthSuccess(response)
        } catch {
            handleAuthError(error)
        }

        isLoading = false
    }

    @MainActor
    func performLogin() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiClient.login(
                LoginRequest(email: email, password: password)
            )
            handleAuthSuccess(response)
        } catch {
            handleAuthError(error)
        }

        isLoading = false
    }

    @MainActor
    func performRegister() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiClient.register(
                RegisterRequest(
                    email: email,
                    password: password,
                    displayName: displayName
                )
            )
            handleAuthSuccess(response)
        } catch {
            handleAuthError(error)
        }

        isLoading = false
    }

    func handleAuthSuccess(_ response: AuthResponse) {
        tokenManager.storeTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
        AppLogger.auth.info("Authenticated as \(response.user.displayName)")
        onAuthenticated?(response.user)
    }

    func handleAuthError(_ error: Error) {
        if let apiError = error as? APIError {
            errorMessage = apiError.message
        } else {
            errorMessage = error.localizedDescription
        }
        AppLogger.auth.error("Auth failed: \(error.localizedDescription)")
    }

    // MARK: - Validation

    func validateLoginFields() -> Bool {
        guard !email.isEmpty else {
            errorMessage = "Email is required"
            return false
        }
        guard !password.isEmpty else {
            errorMessage = "Password is required"
            return false
        }
        return true
    }

    func validateRegisterFields() -> Bool {
        guard validateLoginFields() else { return false }
        guard !displayName.isEmpty else {
            errorMessage = "Display name is required"
            return false
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return false
        }
        return true
    }

    func buildFullName(from nameComponents: PersonNameComponents?) -> String? {
        guard let name = nameComponents else { return nil }
        var parts: [String] = []
        if let given = name.givenName { parts.append(given) }
        if let family = name.familyName { parts.append(family) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
