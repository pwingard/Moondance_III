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
        case marginal   // below required separation but moon isn't too bright — yellow
        case noImaging  // moon too bright for any imaging — red

        var color: Color {
            switch self {
            case .good: return .green
            case .marginal: return .yellow
            case .noImaging: return .red
            }
        }

        var label: String {
            switch self {
            case .good: return "Good"
            case .marginal: return "Marginal"
            case .noImaging: return "No Imaging"
            }
        }

        var symbol: String {
            switch self {
            case .good: return "checkmark.circle.fill"
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
