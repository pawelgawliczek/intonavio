import SwiftUI

struct SignInView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                branding
                Spacer().frame(height: 32)
                authContent
                Spacer()
                signUpLink
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
            .navigationDestination(isPresented: $viewModel.showSignUp) {
                SignUpView(viewModel: viewModel)
            }
            .alert("Error", isPresented: hasError) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .disabled(viewModel.isLoading)
            .onAppear { configureAuth() }
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Subviews

private extension SignInView {
    var branding: some View {
        VStack(spacing: 6) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Intonavio")
                .font(.title.bold())
            Text("Sing better, every day")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var authContent: some View {
        VStack(spacing: 20) {
            socialButtons
            divider
            emailSection
        }
    }

    var socialButtons: some View {
        VStack(spacing: 10) {
            AppleSignInButton { result in
                viewModel.handleAppleSignIn(result: result)
            }

            HStack(spacing: 6) {
                Image(systemName: "g.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Sign in with Google")
                    .foregroundStyle(.secondary)
                Text("· Coming soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2))
            )
        }
    }

    var divider: some View {
        HStack(spacing: 12) {
            Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
            Text("or")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
        }
    }

    var emailSection: some View {
        VStack(spacing: 10) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            Button(action: viewModel.login) {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    var signUpLink: some View {
        Button("Don't have an account? Sign Up") {
            viewModel.showSignUp = true
        }
        .font(.footnote)
    }
}

// MARK: - Configuration

private extension SignInView {
    func configureAuth() {
        viewModel.setOnAuthenticated { [appState] user in
            appState.signIn(user: user)
        }
    }
}

#Preview {
    SignInView()
        .environment(AppState())
}
