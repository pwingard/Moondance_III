import SwiftUI

struct SummaryView: View {
    let result: CalculationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Imaging Recommendations")
                .font(.headline)

            // Stats
            HStack(spacing: 20) {
                statCard(
                    title: "Good Nights",
                    value: "\(goodNights.count)",
                    subtitle: "sep ≥ 90°",
                    color: .green
                )
                statCard(
                    title: "Best Nights",
                    value: "\(bestNights.count)",
                    subtitle: "sep ≥ 90° & phase < 20%",
                    color: .cyan
                )
                statCard(
                    title: "Avoid",
                    value: "\(avoidNights.count)",
                    subtitle: "sep < 30° or phase > 80%",
                    color: .red
                )
            }

            // Best dates
            if !bestNights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Imaging Dates")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)

                    ForEach(bestNights) { day in
                        HStack {
                            Text(day.dateLabel)
                                .fontWeight(.medium)
                            Spacer()
                            Text("Sep: \(day.angularSeparation, specifier: "%.0f")°")
                            Text("Phase: \(day.moonPhase, specifier: "%.0f")%")
                                .foregroundColor(.secondary)
                            if day.imagingWindow.durationHours > 0 {
                                Text("\(day.imagingWindow.durationHours, specifier: "%.1f")h")
                                    .foregroundColor(.green)
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Dates to avoid
            if !avoidNights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dates to Avoid")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    ForEach(avoidNights.prefix(10)) { day in
                        HStack {
                            Text(day.dateLabel)
                                .fontWeight(.medium)
                            Spacer()
                            Text("Sep: \(day.angularSeparation, specifier: "%.0f")°")
                            Text("Phase: \(day.moonPhase, specifier: "%.0f")%")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }

                    if avoidNights.count > 10 {
                        Text("+ \(avoidNights.count - 10) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Stat Card

    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Computed

    /// Nights with separation >= 90 degrees
    private var goodNights: [DayResult] {
        result.days.filter { $0.angularSeparation >= 90 }
    }

    /// Best nights: separation >= 90 AND moon phase < 20%
    private var bestNights: [DayResult] {
        result.days.filter { $0.angularSeparation >= 90 && $0.moonPhase < 20 }
    }

    /// Nights to avoid: separation < 30 OR moon phase > 80%
    private var avoidNights: [DayResult] {
        result.days.filter { $0.angularSeparation < 30 || $0.moonPhase > 80 }
    }
}
