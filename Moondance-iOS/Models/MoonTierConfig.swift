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
        case good       // moon-free or new moon — green
        case allowable  // moon up in non-new tier but separation meets settings — yellow
        case mixed      // some good/allowable time + some no-imaging time — orange
        case noImaging  // doesn't meet settings (separation too low or moon too bright) — red

        var color: Color {
            switch self {
            case .good: return .green
            case .allowable: return .yellow
            case .mixed: return .orange
            case .noImaging: return .red
            }
        }

        var label: String {
            switch self {
            case .good: return "Good"
            case .allowable: return "Allowable"
            case .mixed: return "Mixed"
            case .noImaging: return "No Imaging"
            }
        }

        var symbol: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .allowable: return "checkmark.circle.fill"
            case .mixed: return "circle.lefthalf.filled"
            case .noImaging: return "xmark.circle.fill"
            }
        }
    }

    /// Evaluate imaging conditions for a given moon phase and angular separation.
    /// New tier (0-10%) with met separation → .good; higher tiers with met separation → .allowable;
    /// doesn't meet separation or exceeds maxMoonPhase → .noImaging.
    func evaluate(moonPhase: Double, angularSeparation: Double) -> ImagingRating {
        if moonPhase > maxMoonPhase { return .noImaging }

        let upperBounds = Self.fixedUpperBounds + [maxMoonPhase]
        for i in 0..<min(upperBounds.count, minSeparations.count) {
            if moonPhase <= upperBounds[i] {
                if angularSeparation >= minSeparations[i] {
                    return i == 0 ? .good : .allowable
                } else {
                    return .noImaging
                }
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
            return .good  // Both periods are truly good (new moon)
        }
        if moonUpRating == .allowable {
            return .allowable  // Moon-down is good + moon-up meets settings
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
            case .allowable:
                return (.allowable, "Sep \(String(format: "%.0f", sep))\u{00B0} meets settings at \(String(format: "%.0f", moonPhase))% moon")
            case .noImaging:
                return (.noImaging, "Sep \(String(format: "%.0f", sep))\u{00B0} doesn't meet settings at \(String(format: "%.0f", moonPhase))% moon")
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
        if moonUpRating == .allowable {
            return (.allowable, "\(String(format: "%.1f", hoursMoonDown))h moon-free + \(String(format: "%.1f", hoursMoonUp))h allowable at \(String(format: "%.0f", moonPhase))% moon")
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
