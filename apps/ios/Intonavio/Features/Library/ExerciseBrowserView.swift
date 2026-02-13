import SwiftUI

struct ExerciseBrowserView: View {
    private let categories = ExerciseData.categories

    var body: some View {
        List {
            ForEach(categories) { category in
                Section(category.name) {
                    ForEach(category.exercises) { exercise in
                        exerciseRow(exercise)
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
    func exerciseRow(_ exercise: ExerciseItem) -> some View {
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
            Text("Coming soon")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Data

private struct ExerciseCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let exercises: [ExerciseItem]
}

private struct ExerciseItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
}

private enum ExerciseData {
    static let scales: [ExerciseItem] = [
        ExerciseItem(name: "Major Scale", icon: "arrow.up.right", description: "Ascending and descending"),
        ExerciseItem(name: "Minor Scale", icon: "arrow.down.right", description: "Natural, harmonic, melodic"),
        ExerciseItem(name: "Chromatic", icon: "line.diagonal", description: "Half-step precision training")
    ]

    static let arpeggios: [ExerciseItem] = [
        ExerciseItem(name: "Major Arpeggios", icon: "chart.line.uptrend.xyaxis", description: "Root-3rd-5th-octave"),
        ExerciseItem(name: "Minor Arpeggios", icon: "chart.line.downtrend.xyaxis", description: "Minor triad patterns")
    ]

    static let intervals: [ExerciseItem] = [
        ExerciseItem(name: "Thirds", icon: "3.circle", description: "Major and minor thirds"),
        ExerciseItem(name: "Fifths", icon: "5.circle", description: "Perfect fifths"),
        ExerciseItem(name: "Octaves", icon: "8.circle", description: "Full octave jumps")
    ]

    static let vibrato: [ExerciseItem] = [
        ExerciseItem(name: "Slow Vibrato", icon: "waveform.path.ecg", description: "Wide, controlled"),
        ExerciseItem(name: "Fast Vibrato", icon: "waveform.badge.magnifyingglass", description: "Narrow, quick")
    ]

    static let breathing: [ExerciseItem] = [
        ExerciseItem(name: "Diaphragmatic", icon: "lungs", description: "Deep breathing control"),
        ExerciseItem(name: "Sustained Notes", icon: "timer", description: "Hold notes longer")
    ]

    static let categories: [ExerciseCategory] = [
        ExerciseCategory(name: "Scales", icon: "music.note", exercises: scales),
        ExerciseCategory(name: "Arpeggios", icon: "waveform.path", exercises: arpeggios),
        ExerciseCategory(name: "Intervals", icon: "arrow.up.arrow.down", exercises: intervals),
        ExerciseCategory(name: "Vibrato", icon: "waveform", exercises: vibrato),
        ExerciseCategory(name: "Breathing", icon: "wind", exercises: breathing)
    ]
}

#Preview {
    NavigationStack {
        ExerciseBrowserView()
    }
}
