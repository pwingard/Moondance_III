import Foundation

struct ImagingWindow: Sendable {
    let durationHours: Double
    let startTime: Date?
    let endTime: Date?
}

struct NightWindow: Sendable {
    let sunsetTime: Date
    let sunriseTime: Date
    let darknessStart: Date       // sunset + dusk buffer
    let darknessEnd: Date         // sunrise - dawn buffer
    let darkHours: Double         // darknessEnd - darknessStart in hours
    let midnight: Date            // 00:00 of the next calendar day (center of night)
}

struct TargetVisibilitySpan: Sendable {
    let riseTime: Date            // when target crosses above minAlt (or darknessStart if already up)
    let setTime: Date             // when target crosses below minAlt (or darknessEnd if still up)
    let durationHours: Double

    // Offsets relative to darknessStart, in hours. Used for bar chart positioning.
    let riseOffsetHours: Double
    let setOffsetHours: Double

    // Azimuth and directional min altitude at rise/set transitions
    let riseAzimuth: Double       // azimuth in degrees when target rises above threshold
    let setAzimuth: Double        // azimuth in degrees when target sets below threshold
    let riseMinAlt: Double        // interpolated min altitude at rise azimuth
    let setMinAlt: Double         // interpolated min altitude at set azimuth

    // Whether rise/set are actual threshold crossings vs darkness boundaries
    let alreadyUpAtStart: Bool    // true = target was above threshold when darkness began
    let stillUpAtEnd: Bool        // true = target was still above threshold at dawn
}

/// Per-target results for a single night
struct TargetNightResult: Identifiable, Sendable {
    let id = UUID()
    let targetName: String
    let colorIndex: Int           // 0=cyan, 1=orange, 2=green
    let targetAlt: Double
    let angularSeparation: Double
    let imagingWindow: ImagingWindow
    let visibility: TargetVisibilitySpan?

    // Moon-aware imaging: hours of target visibility during moon-down vs moon-up
    let hoursMoonDown: Double             // hours target is visible while moon is below horizon
    let hoursMoonUp: Double               // hours target is visible while moon is above horizon
    let avgSeparationMoonUp: Double?      // average angular separation during moon-up period
}

/// Moon altitude at a single time step during the night (for background glow rendering)
struct MoonAltitudeSample: Sendable {
    let time: Date
    let altitude: Double   // degrees; negative = below horizon
}

struct DayResult: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let dateLabel: String
    let moonAlt: Double
    let moonPhase: Double

    // Bar chart fields
    let nightWindow: NightWindow?
    let moonVisibility: TargetVisibilitySpan?
    let moonAltitudeProfile: [MoonAltitudeSample]  // moon altitude at ~20-min steps

    // Multi-target results
    let targetResults: [TargetNightResult]

    // MARK: - Backward-compatible computed properties (first target)

    var targetAlt: Double {
        targetResults.first?.targetAlt ?? 0
    }

    var angularSeparation: Double {
        targetResults.first?.angularSeparation ?? 0
    }

    var imagingWindow: ImagingWindow {
        targetResults.first?.imagingWindow ?? ImagingWindow(durationHours: 0, startTime: nil, endTime: nil)
    }

    var targetVisibility: TargetVisibilitySpan? {
        targetResults.first?.visibility
    }
}

struct CalculationResult: Sendable {
    let days: [DayResult]
    let minAltitudeThreshold: Double
    let duskDawnBufferHours: Double
    let targetNames: [String]

    var dates: [String] { days.map { $0.dateLabel } }
    var moonAlt: [Double] { days.map { $0.moonAlt } }
    var moonPhase: [Double] { days.map { $0.moonPhase } }
    var targetAlt: [Double] { days.map { $0.targetAlt } }
    var angularSeparation: [Double] { days.map { $0.angularSeparation } }
}
