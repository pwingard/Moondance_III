import Foundation

struct TargetSuggestion: Identifiable, Sendable {
    let id = UUID()
    let target: Target
    let visibilityHours: Double
    let gapCoverageHours: Double
    let rating: MoonTierConfig.ImagingRating
    let reason: String          // e.g., "1:30–5:45 AM · 3.8h moon-free"
    let visibleFrom: String     // e.g., "1:30 AM"
    let visibleTo: String       // e.g., "5:45 AM"
    let availableFrom: String?  // e.g., "from Mar 15" — nil if available now
}

/// Per-sample-night computed context, reused across all candidates.
private struct NightContext {
    let date: Date
    let darknessStart: Date
    let darknessEnd: Date
    let moonPhase: Double
    let moonVis: TargetVisibilitySpan?
    let gaps: [(Date, Date)]
    let totalGapHours: Double
}

struct SuggestionEngine {

    /// Suggest complementary targets that fill gaps in the user's nightly schedule.
    static func suggest(
        selectedTargets: [Target],
        latitude: Double,
        longitude: Double,
        elevation: Double,
        timezone: String,
        dateRangeDays: Int,
        minAltitudes: [Double],
        moonTierConfig: MoonTierConfig,
        duskDawnBufferHours: Double
    ) -> [TargetSuggestion] {
        guard let tz = TimeZone(identifier: timezone) else { return [] }
        let calendar = Calendar.current

        // Sample 3 nights across the date range: early, middle, late
        let offsets: [Int]
        if dateRangeDays <= 30 {
            offsets = [dateRangeDays / 2]   // short range: just the middle
        } else {
            offsets = [10, dateRangeDays / 2, max(dateRangeDays - 10, dateRangeDays / 2 + 1)]
        }

        let sampleDates = offsets.map { calendar.date(byAdding: .day, value: $0, to: Date())! }

        // Build night contexts
        var contexts: [NightContext] = []
        for sampleDate in sampleDates {
            guard let ctx = buildNightContext(
                date: sampleDate,
                selectedTargets: selectedTargets,
                latitude: latitude, longitude: longitude,
                timezone: tz,
                minAltitudes: minAltitudes,
                duskDawnBufferHours: duskDawnBufferHours
            ) else { continue }
            contexts.append(ctx)
        }

        // Need at least one night with a gap
        guard contexts.contains(where: { $0.totalGapHours >= 0.5 }) else { return [] }

        // Get candidates
        let selectedIds = Set(selectedTargets.map { $0.id })
        let candidates = DataManager.shared.targets.filter { target in
            if selectedIds.contains(target.id) { return false }
            let maxAlt = 90.0 - abs(latitude - target.dec)
            return maxAlt >= 0
        }

        // Date formatter for availability labels
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "MMM d"
        dateFmt.timeZone = tz

        // Time formatter for visibility windows
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        timeFmt.timeZone = tz

        // Score each candidate across all sample nights
        var suggestions: [TargetSuggestion] = []

        for candidate in candidates {
            var bestGapHours: Double = 0
            var bestVis: TargetVisibilitySpan?
            var bestRating: MoonTierConfig.ImagingRating = .noImaging
            var bestReason = ""
            var bestCtx: NightContext?
            var firstAvailableDate: Date?

            for ctx in contexts {
                guard ctx.totalGapHours >= 0.5 else { continue }

                guard let vis = AstronomyEngine.findTargetVisibility(
                    targetRA: candidate.ra, targetDec: candidate.dec,
                    latitude: latitude, longitude: longitude,
                    darknessStart: ctx.darknessStart, darknessEnd: ctx.darknessEnd,
                    minAltitudes: minAltitudes
                ) else { continue }

                let gapHours = overlapHours(span: vis, gaps: ctx.gaps)
                if gapHours < 0.5 { continue }

                // Track first night this candidate has coverage
                if firstAvailableDate == nil {
                    firstAvailableDate = ctx.date
                }

                let moonOverlap = AstronomyEngine.analyzeMoonOverlap(
                    targetRA: candidate.ra, targetDec: candidate.dec,
                    latitude: latitude, longitude: longitude,
                    targetVisibility: vis,
                    moonVisibility: ctx.moonVis,
                    darknessStart: ctx.darknessStart, darknessEnd: ctx.darknessEnd
                )

                let (rating, moonReason) = moonTierConfig.evaluateMoonAwareWithReason(
                    moonPhase: ctx.moonPhase,
                    hoursMoonDown: moonOverlap.hoursMoonDown,
                    hoursMoonUp: moonOverlap.hoursMoonUp,
                    avgSeparationMoonUp: moonOverlap.avgSeparationMoonUp
                )

                if rating == .noImaging { continue }

                // Keep the best night for this candidate
                if gapHours > bestGapHours || (gapHours == bestGapHours && ratingOrder(rating) < ratingOrder(bestRating)) {
                    bestGapHours = gapHours
                    bestVis = vis
                    bestRating = rating
                    bestReason = moonReason
                    bestCtx = ctx
                }
            }

            guard let vis = bestVis, bestGapHours >= 0.5, let _ = bestCtx else { continue }

            let fromStr = timeFmt.string(from: vis.riseTime)
            let toStr = timeFmt.string(from: vis.setTime)
            let reason = "\(fromStr)\u{2013}\(toStr) · \(bestReason)"

            // Determine availability label
            let availableFrom: String?
            if let firstDate = firstAvailableDate, firstDate != contexts.first?.date {
                availableFrom = "from \(dateFmt.string(from: firstDate))"
            } else {
                availableFrom = nil
            }

            suggestions.append(TargetSuggestion(
                target: candidate,
                visibilityHours: vis.durationHours,
                gapCoverageHours: bestGapHours,
                rating: bestRating,
                reason: reason,
                visibleFrom: fromStr,
                visibleTo: toStr,
                availableFrom: availableFrom
            ))
        }

        // Sort: available-now first, then gap coverage descending, then rating
        suggestions.sort { a, b in
            let aFuture = a.availableFrom != nil
            let bFuture = b.availableFrom != nil
            if aFuture != bFuture { return !aFuture }
            if abs(a.gapCoverageHours - b.gapCoverageHours) > 0.5 {
                return a.gapCoverageHours > b.gapCoverageHours
            }
            return ratingOrder(a.rating) < ratingOrder(b.rating)
        }

        return Array(suggestions.prefix(12))
    }

    // MARK: - Helpers

    private static func ratingOrder(_ r: MoonTierConfig.ImagingRating) -> Int {
        switch r {
        case .good: return 0
        case .allowable: return 1
        case .mixed: return 2
        case .noImaging: return 3
        }
    }

    /// Build all per-night data needed for candidate evaluation.
    private static func buildNightContext(
        date: Date,
        selectedTargets: [Target],
        latitude: Double, longitude: Double,
        timezone tz: TimeZone,
        minAltitudes: [Double],
        duskDawnBufferHours: Double
    ) -> NightContext? {
        let calendar = Calendar.current

        var sunsetComps = calendar.dateComponents(in: tz, from: date)
        sunsetComps.hour = 18; sunsetComps.minute = 0; sunsetComps.second = 0
        let sunsetApprox = calendar.date(from: sunsetComps)!
        let sunset = AstronomyEngine.findSunset(near: sunsetApprox, latitude: latitude, longitude: longitude)

        var sunriseComps = calendar.dateComponents(in: tz, from: date)
        sunriseComps.hour = 6; sunriseComps.minute = 0; sunriseComps.second = 0
        let sunriseNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.date(from: sunriseComps)!)!
        let sunrise = AstronomyEngine.findSunrise(near: sunriseNextDay, latitude: latitude, longitude: longitude)

        let darknessStart = sunset.addingTimeInterval(duskDawnBufferHours * 3600)
        let darknessEnd = sunrise.addingTimeInterval(-duskDawnBufferHours * 3600)
        guard darknessEnd > darknessStart else { return nil }

        // Moon
        var obsComps = calendar.dateComponents(in: tz, from: date)
        obsComps.hour = 22; obsComps.minute = 0; obsComps.second = 0
        let obsDate = calendar.date(from: obsComps)!
        let jd = AstronomyEngine.julianDate(from: obsDate)
        let moonEq = AstronomyEngine.moonEquatorial(jd: jd)
        let sunEq = AstronomyEngine.sunEquatorial(jd: jd)
        let elongation = AstronomyEngine.angularSeparationEquatorial(
            ra1: moonEq.ra, dec1: moonEq.dec,
            ra2: sunEq.ra, dec2: sunEq.dec
        )
        let moonPhase = (1.0 - cos(elongation * .pi / 180.0)) / 2.0 * 100.0

        let moonVis = AstronomyEngine.findMoonVisibility(
            latitude: latitude, longitude: longitude,
            darknessStart: darknessStart, darknessEnd: darknessEnd
        )

        // Selected targets' visibility → gaps
        let selectedSpans: [TargetVisibilitySpan] = selectedTargets.compactMap { target in
            AstronomyEngine.findTargetVisibility(
                targetRA: target.ra, targetDec: target.dec,
                latitude: latitude, longitude: longitude,
                darknessStart: darknessStart, darknessEnd: darknessEnd,
                minAltitudes: minAltitudes
            )
        }

        let gaps = findGaps(darknessStart: darknessStart, darknessEnd: darknessEnd, spans: selectedSpans)
        let totalGapHours = gaps.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) / 3600.0 }

        return NightContext(
            date: date,
            darknessStart: darknessStart,
            darknessEnd: darknessEnd,
            moonPhase: moonPhase,
            moonVis: moonVis,
            gaps: gaps,
            totalGapHours: totalGapHours
        )
    }

    /// Find uncovered segments of the darkness window.
    static func findGaps(
        darknessStart: Date, darknessEnd: Date,
        spans: [TargetVisibilitySpan]
    ) -> [(Date, Date)] {
        let sorted = spans.sorted { $0.riseTime < $1.riseTime }

        var merged: [(Date, Date)] = []
        for span in sorted {
            if let last = merged.last, span.riseTime <= last.1 {
                merged[merged.count - 1].1 = max(last.1, span.setTime)
            } else {
                merged.append((span.riseTime, span.setTime))
            }
        }

        var gaps: [(Date, Date)] = []
        var current = darknessStart
        for (start, end) in merged {
            let gapStart = max(current, darknessStart)
            let gapEnd = min(start, darknessEnd)
            if gapEnd > gapStart {
                gaps.append((gapStart, gapEnd))
            }
            current = max(current, end)
        }
        if current < darknessEnd {
            gaps.append((current, darknessEnd))
        }
        return gaps
    }

    /// Calculate hours of a visibility span that overlap with gap intervals.
    static func overlapHours(span: TargetVisibilitySpan, gaps: [(Date, Date)]) -> Double {
        var total: TimeInterval = 0
        for (gapStart, gapEnd) in gaps {
            let overlapStart = max(span.riseTime, gapStart)
            let overlapEnd = min(span.setTime, gapEnd)
            if overlapEnd > overlapStart {
                total += overlapEnd.timeIntervalSince(overlapStart)
            }
        }
        return (total / 3600.0 * 10).rounded() / 10
    }
}
