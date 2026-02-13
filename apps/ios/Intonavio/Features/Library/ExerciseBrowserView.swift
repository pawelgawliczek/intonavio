import SwiftUI

struct ExerciseBrowserView: View {
    var body: some View {
        List {
            ForEach(ExerciseCategory.allCases, id: \.self) { category in
                let exercises = ExerciseDefinitions.exercises(for: category)
                if !exercises.isEmpty {
                    Section(category.rawValue) {
                        ForEach(exercises) { exercise in
                            NavigationLink {
                                ExercisePracticeView(exercise: exercise)
                            } label: {
                                exerciseRow(exercise)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews

private extension ExerciseBrowserView {
    func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        HStack {
            Image(systemName: exercise.icon)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)
                Text(exercise.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(exercise.defaultTempo) BPM")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseBrowserView()
    }
}
