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
        Chart {
            ForEach(chronological) { record in
                LineMark(
                    x: .value("Date", record.date),
                    y: .value("Score", record.score),
                    series: .value("Scores", "scores")
                )
                .foregroundStyle(Color.intonavioMagenta)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", record.date),
                    y: .value("Score", record.score)
                )
                .foregroundStyle(colorForScore(record.score))
                .symbolSize(record.score == bestScore ? 60 : 30)
            }

            if let trend = trendLine {
                LineMark(
                    x: .value("Date", trend.startDate),
                    y: .value("Score", trend.startScore),
                    series: .value("Trend", "trend")
                )
                .foregroundStyle(Color.intonavioIce.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

                LineMark(
                    x: .value("Date", trend.endDate),
                    y: .value("Score", trend.endScore),
                    series: .value("Trend", "trend")
                )
                .foregroundStyle(Color.intonavioIce.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .chartLegend(.hidden)
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

    struct TrendEndpoints {
        let startDate: Date
        let startScore: Double
        let endDate: Date
        let endScore: Double
    }

    var trendLine: TrendEndpoints? {
        let sorted = chronological
        guard sorted.count >= 2 else { return nil }

        let firstTime = sorted[0].date.timeIntervalSinceReferenceDate
        let xs = sorted.map { $0.date.timeIntervalSinceReferenceDate - firstTime }
        let ys = sorted.map(\.score)
        let n = Double(xs.count)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        let startScore = max(0, min(100, intercept))
        let endScore = max(0, min(100, slope * xs.last! + intercept))

        return TrendEndpoints(
            startDate: sorted.first!.date,
            startScore: startScore,
            endDate: sorted.last!.date,
            endScore: endScore
        )
    }

    func colorForScore(_ score: Double) -> Color {
        if score > 80 { return .intonavioAmber }
        if score > 50 { return .intonavioMagenta }
        if score > 30 { return .intonavioIce.opacity(0.7) }
        return .intonavioTextSecondary
    }
}

#Preview {
    ScoreHistoryChartView(scores: [])
        .padding()
        .background(Color.intonavioBackground)
}
