import Foundation
import SwiftUI

/// Configurable moon brightness tiers that determine imaging feasibility.
/// Each tier maps a range of moon illumination percentages to a minimum
/// angular separation required between moon and target for good imaging.
struct MoonTierConfig: Codable, Equatable {
    /// Minimum angular separation (degrees) required for each of 4 tiers.
    /// [0]: 0–10% moon, [1]: 11–25%, [2]: 26–50%, [3]: 51–maxMoonPhase%
    var minSeparations: [Double]

    /// Moon illumination above this percentage means no imaging.
    var maxMoonPhase: Double

    static let tierNames = ["New Tier", "Crescent Tier", "Quarter Tier", "Gibbous Tier"]
    static let fixedLowerBounds: [Double] = [0, 11, 26, 51]
    static let fixedUpperBounds: [Double] = [10, 25, 50] // tier 3 upper = maxMoonPhase

    static let defaults = MoonTierConfig(
        minSeparations: [10, 30, 60, 90],
        maxMoonPhase: 75
    )

    /// Imaging quality rating for a given night/target combination.
    enum ImagingRating {
        case good       // meets angular separation requirement — green
        case mixed      // some good time (moon down) + some bad time (moon up) — orange
        case marginal   // below required separation but moon isn't too bright — yellow
        case noImaging  // moon too bright for any imaging — red

        var color: Color {
            switch self {
            case .good: return .green
            case .mixed: return .orange
            case .marginal: return .yellow
            case .noImaging: return .red
            }
        }

        var label: String {
            switch self {
            case .good: return "Good"
            case .mixed: return "Mixed"
            case .marginal: return "Marginal"
            case .noImaging: return "No Imaging"
            }
        }

        var symbol: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .mixed: return "circle.lefthalf.filled"
            case .marginal: return "exclamationmark.triangle.fill"
            case .noImaging: return "xmark.circle.fill"
            }
        }
    }

    /// Evaluate imaging conditions for a given moon phase and angular separation.
    func evaluate(moonPhase: Double, angularSeparation: Double) -> ImagingRating {
        if moonPhase > maxMoonPhase { return .noImaging }

        let upperBounds = Self.fixedUpperBounds + [maxMoonPhase]
        for i in 0..<min(upperBounds.count, minSeparations.count) {
            if moonPhase <= upperBounds[i] {
                return angularSeparation >= minSeparations[i] ? .good : .marginal
            }
        }
        return .noImaging
    }

    /// Moon-aware evaluation: considers when the moon is above/below the horizon.
    /// Moon below horizon = always good imaging, regardless of phase.
    func evaluateMoonAware(
        moonPhase: Double,
        hoursMoonDown: Double,
        hoursMoonUp: Double,
        avgSeparationMoonUp: Double?
    ) -> ImagingRating {
        // Target not visible at all
        if hoursMoonDown <= 0 && hoursMoonUp <= 0 { return .noImaging }

        // All visibility is moon-down → always good
        if hoursMoonUp <= 0 { return .good }

        // All visibility is moon-up → standard evaluation
        if hoursMoonDown <= 0 {
            return evaluate(moonPhase: moonPhase, angularSeparation: avgSeparationMoonUp ?? 0)
        }

        // Mixed: some moon-down (good) + some moon-up (evaluate)
        let moonUpRating = evaluate(moonPhase: moonPhase, angularSeparation: avgSeparationMoonUp ?? 0)
        if moonUpRating == .good {
            return .good  // Both periods are good
        }

        // Has good moon-down time but moon-up time is marginal or bad
        return .mixed
    }

    /// Moon-aware evaluation with reason string explaining why.
    func evaluateMoonAwareWithReason(
        moonPhase: Double,
        hoursMoonDown: Double,
        hoursMoonUp: Double,
        avgSeparationMoonUp: Double?
    ) -> (rating: ImagingRating, reason: String) {
        if hoursMoonDown <= 0 && hoursMoonUp <= 0 {
            return (.noImaging, "Target not visible")
        }

        if hoursMoonUp <= 0 {
            return (.good, "Moon below horizon (\(String(format: "%.1f", hoursMoonDown))h moon-free)")
        }

        if hoursMoonDown <= 0 {
            let sep = avgSeparationMoonUp ?? 0
            let r = evaluate(moonPhase: moonPhase, angularSeparation: sep)
            switch r {
            case .good:
                return (.good, "Sep \(String(format: "%.0f", sep))\u{00B0} OK at \(String(format: "%.0f", moonPhase))% moon")
            case .marginal:
                return (.marginal, "Sep \(String(format: "%.0f", sep))\u{00B0} low at \(String(format: "%.0f", moonPhase))% moon")
            case .noImaging:
                return (.noImaging, "Moon \(String(format: "%.0f", moonPhase))% too bright")
            case .mixed:
                return (.mixed, "")
            }
        }

        // Mixed periods
        let sep = avgSeparationMoonUp ?? 0
        let moonUpRating = evaluate(moonPhase: moonPhase, angularSeparation: sep)
        if moonUpRating == .good {
            return (.good, "\(String(format: "%.1f", hoursMoonDown))h moon-free + sep \(String(format: "%.0f", sep))\u{00B0} OK")
        }

        return (.mixed, "\(String(format: "%.1f", hoursMoonDown))h moon-free, \(String(format: "%.1f", hoursMoonUp))h at \(String(format: "%.0f", moonPhase))% moon")
    }

    /// Human-readable range label for a tier index (e.g. "0–10%")
    func tierRangeLabel(_ index: Int) -> String {
        let lower = Int(Self.fixedLowerBounds[index])
        let upper = index < Self.fixedUpperBounds.count
            ? Int(Self.fixedUpperBounds[index])
            : Int(maxMoonPhase)
        return "\(lower)–\(upper)%"
    }

    var jsonString: String {
        (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "{}"
    }

    static func from(jsonString: String) -> MoonTierConfig {
        guard let data = jsonString.data(using: .utf8),
              let config = try? JSONDecoder().decode(MoonTierConfig.self, from: data)
        else { return .defaults }
        return config
    }
}
