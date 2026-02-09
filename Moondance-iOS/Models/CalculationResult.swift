import Foundation

struct ImagingWindow: Sendable {
    let durationHours: Double
    let startTime: Date?
    let endTime: Date?
}

struct DayResult: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let dateLabel: String
    let moonAlt: Double
    let moonPhase: Double
    let targetAlt: Double
    let angularSeparation: Double
    let imagingWindow: ImagingWindow
}

struct CalculationResult: Sendable {
    let days: [DayResult]

    var dates: [String] { days.map { $0.dateLabel } }
    var moonAlt: [Double] { days.map { $0.moonAlt } }
    var moonPhase: [Double] { days.map { $0.moonPhase } }
    var targetAlt: [Double] { days.map { $0.targetAlt } }
    var angularSeparation: [Double] { days.map { $0.angularSeparation } }
}
