import SwiftUI

struct ExercisePracticeView: View {
    var body: some View {
        VStack {
            Text("Exercise Practice — Coming in Phase 5")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ExercisePracticeView()
    }
}
