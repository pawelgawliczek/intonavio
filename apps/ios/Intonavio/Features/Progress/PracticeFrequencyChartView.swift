import Charts
import SwiftUI

/// Bar chart showing how many practice attempts were made per day.
struct PracticeFrequencyChartView: View {
    let scores: [ScoreRecord]

    @State private var timeRange: TimeRange = .week

    var body: some View {
        if scores.isEmpty {
            emptyState
        } else {
            VStack(spacing: 8) {
                Picker("Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                chart
            }
        }
    }
}

// MARK: - Time Range

extension PracticeFrequencyChartView {
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "7D"
        case month = "30D"
        case allTime = "All"

        var id: String { rawValue }

        var label: String { rawValue }

        var startDate: Date? {
            switch self {
            case .week:
                return Calendar.current.date(byAdding: .day, value: -6, to: .now)
            case .month:
                return Calendar.current.date(byAdding: .day, value: -29, to: .now)
            case .allTime:
                return nil
            }
        }
    }
}

// MARK: - Subviews

private extension PracticeFrequencyChartView {
    var chart: some View {
        Chart(groupedByDay) { bucket in
            BarMark(
                x: .value("Date", bucket.date, unit: .day),
                y: .value("Attempts", bucket.count)
            )
            .foregroundStyle(LinearGradient.intonavio)
            .cornerRadius(3)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.intonavioTextSecondary.opacity(0.3))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.caption2)
                            .foregroundStyle(Color.intonavioTextSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xStride)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: xLabelFormat)
                            .font(.caption2)
                            .foregroundStyle(Color.intonavioTextSecondary)
                    }
                }
            }
        }
        .frame(height: 140)
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(Color.intonavioTextSecondary)
            Text("Practice regularly to see your activity")
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data

private extension PracticeFrequencyChartView {
    struct DayBucket: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    var filteredScores: [ScoreRecord] {
        guard let start = timeRange.startDate else { return scores }
        let startOfDay = Calendar.current.startOfDay(for: start)
        return scores.filter { $0.date >= startOfDay }
    }

    var groupedByDay: [DayBucket] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]

        for record in filteredScores {
            let day = calendar.startOfDay(for: record.date)
            counts[day, default: 0] += 1
        }

        return counts.map { DayBucket(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }

    var xStride: Calendar.Component {
        switch timeRange {
        case .week: return .day
        case .month: return .weekOfYear
        case .allTime: return .month
        }
    }

    var xLabelFormat: Date.FormatStyle {
        switch timeRange {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.month(.abbreviated).day()
        case .allTime:
            return .dateTime.month(.abbreviated)
        }
    }
}

#Preview {
    PracticeFrequencyChartView(scores: [])
        .padding()
        .background(Color.intonavioBackground)
}
