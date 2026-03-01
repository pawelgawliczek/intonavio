import SwiftUI

/// Horizontal scroll section showing exercise categories on HomeView.
struct ExerciseSectionView: View {
    private let categories = [
        ExerciseEntry(name: "Scales", icon: "music.note"),
        ExerciseEntry(name: "Arpeggios", icon: "waveform.path"),
        ExerciseEntry(name: "Intervals", icon: "arrow.up.arrow.down"),
        ExerciseEntry(name: "Vibrato", icon: "waveform"),
        ExerciseEntry(name: "Breathing", icon: "wind")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    NavigationLink {
                        ExerciseBrowserView()
                    } label: {
                        categoryCard(category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func categoryCard(_ category: ExerciseEntry) -> some View {
        VStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(Color.intonavioIce)
                .frame(width: 60, height: 60)
                .background(Color.intonavioSurface, in: RoundedRectangle(cornerRadius: 12))
            Text(category.name)
                .font(.caption)
                .foregroundStyle(.white)
        }
        .frame(width: 80)
    }
}

private struct ExerciseEntry: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

#Preview {
    NavigationStack {
        ExerciseSectionView()
    }
}
