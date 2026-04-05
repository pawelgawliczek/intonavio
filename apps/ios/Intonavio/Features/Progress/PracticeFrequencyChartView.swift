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
        Chart {
            ForEach(groupedByDay) { bucket in
                BarMark(
                    x: .value("Date", bucket.date, unit: .day),
                    y: .value("Attempts", bucket.count)
                )
                .foregroundStyle(Color.intonavioAmber.opacity(0.8))
                .cornerRadius(3)
            }

            if let trend = frequencyTrendLine {
                LineMark(
                    x: .value("Date", trend.startDate),
                    y: .value("Attempts", trend.startValue),
                    series: .value("Trend", "trend")
                )
                .foregroundStyle(Color.intonavioIce.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

                LineMark(
                    x: .value("Date", trend.endDate),
                    y: .value("Attempts", trend.endValue),
                    series: .value("Trend", "trend")
                )
                .foregroundStyle(Color.intonavioIce.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
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

    struct TrendEndpoints {
        let startDate: Date
        let startValue: Double
        let endDate: Date
        let endValue: Double
    }

    var frequencyTrendLine: TrendEndpoints? {
        let buckets = groupedByDay
        guard buckets.count >= 2 else { return nil }

        let firstTime = buckets[0].date.timeIntervalSinceReferenceDate
        let xs = buckets.map { $0.date.timeIntervalSinceReferenceDate - firstTime }
        let ys = buckets.map { Double($0.count) }
        let n = Double(xs.count)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        return TrendEndpoints(
            startDate: buckets.first!.date,
            startValue: max(0, intercept),
            endDate: buckets.last!.date,
            endValue: max(0, slope * xs.last! + intercept)
        )
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
