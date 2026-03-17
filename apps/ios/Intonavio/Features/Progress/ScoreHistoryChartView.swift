import Charts
import SwiftUI

/// Line chart showing song-level scores over time.
struct ScoreHistoryChartView: View {
    let scores: [ScoreRecord]

    var body: some View {
        if scores.isEmpty {
            emptyState
        } else {
            chart
        }
    }
}

// MARK: - Subviews

private extension ScoreHistoryChartView {
    var chart: some View {
        Chart(chronological) { record in
            LineMark(
                x: .value("Date", record.date),
                y: .value("Score", record.score)
            )
            .foregroundStyle(LinearGradient.intonavio)
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", record.date),
                y: .value("Score", record.score)
            )
            .foregroundStyle(colorForScore(record.score))
            .symbolSize(record.score == bestScore ? 60 : 30)
        }
        .chartYScale(domain: 0 ... 100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.intonavioTextSecondary.opacity(0.3))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)%")
                            .font(.caption2)
                            .foregroundStyle(Color.intonavioTextSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(Color.intonavioTextSecondary)
                    }
                }
            }
        }
        .frame(height: 180)
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.title2)
                .foregroundStyle(Color.intonavioTextSecondary)
            Text("Sing through the full song to see your progress")
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helpers

private extension ScoreHistoryChartView {
    var chronological: [ScoreRecord] {
        scores.sorted { $0.date < $1.date }
    }

    var bestScore: Double {
        scores.map(\.score).max() ?? 0
    }

    func colorForScore(_ score: Double) -> Color {
        if score > 80 { return .green }
        if score > 50 { return .yellow }
        if score > 30 { return .orange }
        return .gray
    }
}

#Preview {
    ScoreHistoryChartView(scores: [])
        .padding()
        .background(Color.intonavioBackground)
}
