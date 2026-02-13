import SwiftUI

struct SummaryView: View {
    let result: CalculationResult
    var moonTierConfig: MoonTierConfig = .defaults

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Imaging Recommendations")
                .font(.headline)

            // Stats
            HStack(spacing: 8) {
                statCard(
                    title: "Good",
                    value: "\(goodNights.count)",
                    subtitle: "moon-free",
                    color: .green
                )
                statCard(
                    title: "Allowable",
                    value: "\(allowableNights.count)",
                    subtitle: "meets settings",
                    color: .yellow
                )
                statCard(
                    title: "Mixed",
                    value: "\(mixedNights.count)",
                    subtitle: "partial moon",
                    color: .orange
                )
                statCard(
                    title: "Avoid",
                    value: "\(noImagingNights.count)",
                    subtitle: "moon too bright",
                    color: .red
                )
            }

            // Best dates
            if !goodNights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Imaging Dates")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)

                    ForEach(goodNights.prefix(12)) { day in
                        HStack {
                            Text(day.dateLabel)
                                .fontWeight(.medium)
                            Spacer()
                            Text("Sep: \(day.angularSeparation, specifier: "%.0f")\u{00B0}")
                            Text("Moon: \(day.moonPhase, specifier: "%.0f")%")
                                .foregroundColor(.secondary)
                            if day.imagingWindow.durationHours > 0 {
                                Text("\(day.imagingWindow.durationHours, specifier: "%.1f")h")
                                    .foregroundColor(.green)
                            }
                        }
                        .font(.caption)
                    }

                    if goodNights.count > 12 {
                        Text("+ \(goodNights.count - 12) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Dates to avoid
            if !noImagingNights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dates to Avoid")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    ForEach(noImagingNights.prefix(10)) { day in
                        HStack {
                            Text(day.dateLabel)
                                .fontWeight(.medium)
                            Spacer()
                            Text("Moon: \(day.moonPhase, specifier: "%.0f")%")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }

                    if noImagingNights.count > 10 {
                        Text("+ \(noImagingNights.count - 10) more")
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

    // MARK: - Computed (using first target for backward compatibility)

    private func ratingForDay(_ day: DayResult) -> MoonTierConfig.ImagingRating {
        guard let first = day.targetResults.first else { return .noImaging }
        return moonTierConfig.evaluateMoonAware(
            moonPhase: day.moonPhase,
            hoursMoonDown: first.hoursMoonDown,
            hoursMoonUp: first.hoursMoonUp,
            avgSeparationMoonUp: first.avgSeparationMoonUp
        )
    }

    private var goodNights: [DayResult] {
        result.days.filter { ratingForDay($0) == .good }
    }

    private var allowableNights: [DayResult] {
        result.days.filter { ratingForDay($0) == .allowable }
    }

    private var mixedNights: [DayResult] {
        result.days.filter { ratingForDay($0) == .mixed }
    }

    private var noImagingNights: [DayResult] {
        result.days.filter { ratingForDay($0) == .noImaging }
    }
}
