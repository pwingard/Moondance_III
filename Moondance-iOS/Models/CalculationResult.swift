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
}

/// Per-target results for a single night
struct TargetNightResult: Sendable {
    let targetName: String
    let colorIndex: Int           // 0=cyan, 1=orange, 2=green
    let targetAlt: Double
    let angularSeparation: Double
    let imagingWindow: ImagingWindow
    let visibility: TargetVisibilitySpan?
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
