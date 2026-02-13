import AuthenticationServices
import SwiftUI

/// Wrapped SignInWithAppleButton that passes results to AuthViewModel.
struct AppleSignInButton: View {
    let onResult: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            onResult(result)
        }
        .signInWithAppleButtonStyle(.whiteOutline)
        .frame(height: 44)
    }
}

#Preview {
    AppleSignInButton { _ in }
        .padding()
}
