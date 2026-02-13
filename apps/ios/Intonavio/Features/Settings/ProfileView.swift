import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                avatarHeader
            }

            Section("Details") {
                infoRow("Display Name", value: user?.displayName)
                infoRow("Email", value: user?.email)
                infoRow("User ID", value: user?.id)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var user: AuthUser? {
        appState.currentUser
    }
}

// MARK: - Subviews

private extension ProfileView {
    var avatarHeader: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                Text(user?.displayName ?? "User")
                    .font(.title2.bold())
                if let email = user?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            Spacer()
        }
    }

    func infoRow(_ label: String, value: String?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—")
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(AppState())
}
