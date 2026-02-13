import SwiftUI

struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.title.bold())

                formFields
                registerButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews

private extension SignUpView {
    var formFields: some View {
        VStack(spacing: 12) {
            TextField("Display Name", text: $viewModel.displayName)
                .textContentType(.name)
                .textFieldStyle(.roundedBorder)

            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            SecureField("Password (min 8 characters)", text: $viewModel.password)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
        }
    }

    var registerButton: some View {
        Button(action: viewModel.register) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Create Account")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

#Preview {
    NavigationStack {
        SignUpView(viewModel: AuthViewModel(apiClient: MockAPIClient()))
    }
}
