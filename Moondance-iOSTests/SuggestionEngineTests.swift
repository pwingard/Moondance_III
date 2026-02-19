import Testing
import Foundation
@testable import Moondance_iOS

@Suite("SuggestionEngine")
struct SuggestionEngineTests {

    // MARK: - Helpers

    /// Builds a TargetVisibilitySpan purely from rise/set times for test use.
    private func span(rise: Date, set: Date) -> TargetVisibilitySpan {
        TargetVisibilitySpan(
            riseTime: rise, setTime: set,
            durationHours: set.timeIntervalSince(rise) / 3600,
            riseOffsetHours: 0, setOffsetHours: 0,
            riseAzimuth: 0, setAzimuth: 0,
            riseMinAlt: 20, setMinAlt: 20,
            alreadyUpAtStart: false, stillUpAtEnd: false
        )
    }

    /// Reference night: 8 PM to 5 AM (9 hours of darkness)
    private let dusk  = Date(timeIntervalSinceReferenceDate: 0)         // T+0h
    private var dawn: Date { dusk.addingTimeInterval(9 * 3600) }         // T+9h
    private func t(_ hours: Double) -> Date {
        dusk.addingTimeInterval(hours * 3600)
    }

    // MARK: - findGaps

    @Test func noSpans_fullNightIsOneGap() {
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [])
        #expect(gaps.count == 1)
        #expect(gaps[0].0 == dusk)
        #expect(gaps[0].1 == dawn)
    }

    @Test func spanCoversFullNight_noGaps() {
        let s = span(rise: dusk, set: dawn)
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [s])
        #expect(gaps.isEmpty)
    }

    @Test func spanInMiddle_twoGaps() {
        // Target visible 3h–6h → gaps are 0–3h and 6–9h
        let s = span(rise: t(3), set: t(6))
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [s])
        #expect(gaps.count == 2)
        #expect(gaps[0].0 == dusk)
        #expect(gaps[0].1 == t(3))
        #expect(gaps[1].0 == t(6))
        #expect(gaps[1].1 == dawn)
    }

    @Test func spanAtStart_oneGapAtEnd() {
        let s = span(rise: dusk, set: t(4))
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [s])
        #expect(gaps.count == 1)
        #expect(gaps[0].0 == t(4))
        #expect(gaps[0].1 == dawn)
    }

    @Test func spanAtEnd_oneGapAtStart() {
        let s = span(rise: t(5), set: dawn)
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [s])
        #expect(gaps.count == 1)
        #expect(gaps[0].0 == dusk)
        #expect(gaps[0].1 == t(5))
    }

    @Test func twoNonOverlappingSpans_threeGaps() {
        let s1 = span(rise: t(1), set: t(3))
        let s2 = span(rise: t(5), set: t(7))
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [s1, s2])
        #expect(gaps.count == 3)
        #expect(gaps[0].0 == dusk);  #expect(gaps[0].1 == t(1))
        #expect(gaps[1].0 == t(3));  #expect(gaps[1].1 == t(5))
        #expect(gaps[2].0 == t(7));  #expect(gaps[2].1 == dawn)
    }

    @Test func overlappingSpansMerge() {
        // Two spans that overlap should be treated as one block
        let s1 = span(rise: t(1), set: t(5))
        let s2 = span(rise: t(3), set: t(7))  // overlaps s1
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [s1, s2])
        #expect(gaps.count == 2)
        #expect(gaps[0].0 == dusk);  #expect(gaps[0].1 == t(1))
        #expect(gaps[1].0 == t(7));  #expect(gaps[1].1 == dawn)
    }

    @Test func unsortedSpansHandledCorrectly() {
        // Spans provided out of chronological order — should still produce correct gaps
        let s1 = span(rise: t(5), set: t(7))
        let s2 = span(rise: t(1), set: t(3))
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [s1, s2])
        #expect(gaps.count == 3)
    }

    @Test func spanExtendsBeyondDarkness_clampedCorrectly() {
        // Span starts before dusk or ends after dawn — gaps should be clamped to darkness
        let s = span(rise: t(-1), set: t(10))  // wider than darkness window
        let gaps = SuggestionEngine.findGaps(darknessStart: dusk, darknessEnd: dawn, spans: [s])
        #expect(gaps.isEmpty)
    }

    // MARK: - overlapHours

    @Test func overlapHours_noOverlap() {
        let s = span(rise: t(0), set: t(3))
        let gaps: [(Date, Date)] = [(t(5), t(8))]
        #expect(SuggestionEngine.overlapHours(span: s, gaps: gaps) == 0)
    }

    @Test func overlapHours_fullOverlap() {
        let s = span(rise: t(1), set: t(4))
        let gaps: [(Date, Date)] = [(t(0), t(5))]
        let hours = SuggestionEngine.overlapHours(span: s, gaps: gaps)
        #expect(abs(hours - 3.0) < 0.1)
    }

    @Test func overlapHours_partialOverlapAtStart() {
        let s = span(rise: t(0), set: t(4))
        let gaps: [(Date, Date)] = [(t(2), t(6))]
        let hours = SuggestionEngine.overlapHours(span: s, gaps: gaps)
        #expect(abs(hours - 2.0) < 0.1)
    }

    @Test func overlapHours_partialOverlapAtEnd() {
        let s = span(rise: t(2), set: t(6))
        let gaps: [(Date, Date)] = [(t(0), t(4))]
        let hours = SuggestionEngine.overlapHours(span: s, gaps: gaps)
        #expect(abs(hours - 2.0) < 0.1)
    }

    @Test func overlapHours_multipleGaps() {
        let s = span(rise: t(0), set: t(9))
        let gaps: [(Date, Date)] = [(t(1), t(3)), (t(6), t(8))]
        let hours = SuggestionEngine.overlapHours(span: s, gaps: gaps)
        #expect(abs(hours - 4.0) < 0.1)  // 2h + 2h
    }

    @Test func overlapHours_emptyGapList() {
        let s = span(rise: t(0), set: t(5))
        #expect(SuggestionEngine.overlapHours(span: s, gaps: []) == 0)
    }
}
