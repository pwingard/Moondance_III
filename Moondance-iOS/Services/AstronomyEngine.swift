import Foundation

/// Pure-Swift astronomy calculation engine.
/// Ports the Python/astropy calculate.py to on-device math using
/// algorithms from Jean Meeus "Astronomical Algorithms".
nonisolated struct AstronomyEngine: Sendable {

    // MARK: - Public API

    /// Calculate moon and target data over a date range.
    /// Accepts arrays for multi-target comparison (up to 3 targets).
    static func calculate(
        latitude: Double,
        longitude: Double,
        elevation: Double,
        timezone: String,
        targetRAs: [Double],      // degrees
        targetDecs: [Double],     // degrees
        targetNames: [String],
        startDate: Date,
        endDate: Date,
        observationHour: Int,
        minAltitudes: [Double] = [30, 30, 30, 30, 30, 30, 30, 30],
        duskDawnBufferHours: Double = 1.0
    ) -> CalculationResult {
        let tz = TimeZone(identifier: timezone) ?? .current
        let calendar = Calendar.current

        var days: [DayResult] = []
        var current = startDate

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.timeZone = tz

        while current <= endDate {
            // Build observation datetime in the user's timezone
            var comps = calendar.dateComponents(in: tz, from: current)
            comps.hour = observationHour
            comps.minute = 0
            comps.second = 0
            guard let obsDate = calendar.date(from: comps) else {
                current = calendar.date(byAdding: .day, value: 1, to: current)!
                continue
            }

            let jd = julianDate(from: obsDate)

            // Moon position
            let moonEq = moonEquatorial(jd: jd)
            let moonAltAz = equatorialToAltAz(
                ra: moonEq.ra, dec: moonEq.dec,
                jd: jd, lat: latitude, lon: longitude
            )

            // Sun position (for phase)
            let sunEq = sunEquatorial(jd: jd)

            // Moon phase (illumination %)
            let elongation = angularSeparationEquatorial(
                ra1: moonEq.ra, dec1: moonEq.dec,
                ra2: sunEq.ra, dec2: sunEq.dec
            )
            let phase = (1.0 - cos(elongation.degreesToRadians)) / 2.0 * 100.0

            // Bar chart: find sunset/sunrise (shared across all targets)
            var sunsetComps = calendar.dateComponents(in: tz, from: current)
            sunsetComps.hour = 18; sunsetComps.minute = 0; sunsetComps.second = 0
            let sunsetApprox = calendar.date(from: sunsetComps)!
            let sunset = findSunset(near: sunsetApprox, latitude: latitude, longitude: longitude)

            var sunriseComps = calendar.dateComponents(in: tz, from: current)
            sunriseComps.hour = 6; sunriseComps.minute = 0; sunriseComps.second = 0
            let sunriseNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.date(from: sunriseComps)!)!
            let sunrise = findSunrise(near: sunriseNextDay, latitude: latitude, longitude: longitude)

            let darknessStart = sunset.addingTimeInterval(duskDawnBufferHours * 3600)
            let darknessEnd = sunrise.addingTimeInterval(-duskDawnBufferHours * 3600)
            let darkHours = max(0, darknessEnd.timeIntervalSince(darknessStart) / 3600.0)

            // Midnight = 00:00 of the next calendar day (center of the observing night)
            var midnightComps = calendar.dateComponents(in: tz, from: current)
            midnightComps.hour = 0; midnightComps.minute = 0; midnightComps.second = 0
            let midnightToday = calendar.date(from: midnightComps)!
            let midnight = calendar.date(byAdding: .day, value: 1, to: midnightToday)!

            let nightWin = NightWindow(
                sunsetTime: sunset,
                sunriseTime: sunrise,
                darknessStart: darknessStart,
                darknessEnd: darknessEnd,
                darkHours: (darkHours * 10).rounded() / 10,
                midnight: midnight
            )

            // Moon visibility during darkness
            let moonVis = findMoonVisibility(
                latitude: latitude, longitude: longitude,
                darknessStart: darknessStart, darknessEnd: darknessEnd
            )

            // Moon altitude profile for background glow (20-minute steps)
            let moonProfile = computeMoonAltitudeProfile(
                latitude: latitude, longitude: longitude,
                darknessStart: darknessStart, darknessEnd: darknessEnd
            )

            // Calculate per-target results
            var targetResults: [TargetNightResult] = []
            for i in 0..<targetRAs.count {
                let tRA = targetRAs[i]
                let tDec = targetDecs[i]
                let tName = targetNames[i]

                let targetAltAz = equatorialToAltAz(
                    ra: tRA, dec: tDec,
                    jd: jd, lat: latitude, lon: longitude
                )

                let separation = angularSeparationAltAz(
                    alt1: moonAltAz.alt, az1: moonAltAz.az,
                    alt2: targetAltAz.alt, az2: targetAltAz.az
                )

                let window = calculateImagingWindow(
                    targetRA: tRA, targetDec: tDec,
                    latitude: latitude, longitude: longitude,
                    obsDate: obsDate, tz: tz, calendar: calendar
                )

                let visibility = findTargetVisibility(
                    targetRA: tRA, targetDec: tDec,
                    latitude: latitude, longitude: longitude,
                    darknessStart: darknessStart, darknessEnd: darknessEnd,
                    minAltitudes: minAltitudes
                )

                // Moon-aware analysis: how much of target's visibility overlaps with moon up/down
                let moonAnalysis = analyzeMoonOverlap(
                    targetRA: tRA, targetDec: tDec,
                    latitude: latitude, longitude: longitude,
                    targetVisibility: visibility,
                    moonVisibility: moonVis,
                    darknessStart: darknessStart,
                    darknessEnd: darknessEnd
                )

                targetResults.append(TargetNightResult(
                    targetName: tName,
                    colorIndex: i,
                    targetAlt: (targetAltAz.alt * 10).rounded() / 10,
                    angularSeparation: (separation * 10).rounded() / 10,
                    imagingWindow: window,
                    visibility: visibility,
                    hoursMoonDown: moonAnalysis.hoursMoonDown,
                    hoursMoonUp: moonAnalysis.hoursMoonUp,
                    avgSeparationMoonUp: moonAnalysis.avgSeparationMoonUp
                ))
            }

            days.append(DayResult(
                date: current,
                dateLabel: formatter.string(from: current),
                moonAlt: (moonAltAz.alt * 10).rounded() / 10,
                moonPhase: phase.rounded(),
                nightWindow: nightWin,
                moonVisibility: moonVis,
                moonAltitudeProfile: moonProfile,
                targetResults: targetResults
            ))

            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return CalculationResult(
            days: days,
            minAltitudeThreshold: minAltitudes.reduce(0, +) / Double(max(minAltitudes.count, 1)),
            duskDawnBufferHours: duskDawnBufferHours,
            targetNames: targetNames
        )
    }

    // MARK: - Julian Date

    static func julianDate(from date: Date) -> Double {
        // J2000.0 = 2451545.0 = 2000-01-01 12:00 TT
        // Unix epoch (1970-01-01 00:00 UTC) = JD 2440587.5
        return date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    static func dateFromJD(_ jd: Double) -> Date {
        return Date(timeIntervalSince1970: (jd - 2440587.5) * 86400.0)
    }

    // MARK: - Sun Position (low-precision, ~1 arcmin)

    /// Returns Sun RA/Dec in degrees for a given Julian Date.
    static func sunEquatorial(jd: Double) -> (ra: Double, dec: Double) {
        let T = (jd - 2451545.0) / 36525.0 // centuries from J2000

        // Mean longitude (degrees)
        let L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T).mod(360)
        // Mean anomaly (degrees)
        let M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T).mod(360)
        let Mrad = M.degreesToRadians

        // Equation of center
        let C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(Mrad)
            + (0.019993 - 0.000101 * T) * sin(2 * Mrad)
            + 0.000289 * sin(3 * Mrad)

        // Sun's true longitude
        let sunLon = (L0 + C).mod(360)

        // Obliquity of ecliptic
        let omega = (125.04 - 1934.136 * T).degreesToRadians
        let epsilon = 23.4393 - 0.01300 * T + 0.00256 * cos(omega)
        let epsRad = epsilon.degreesToRadians

        let sunLonRad = sunLon.degreesToRadians

        // RA and Dec
        let ra = atan2(cos(epsRad) * sin(sunLonRad), cos(sunLonRad)).radiansToDegrees.mod(360)
        let dec = asin(sin(epsRad) * sin(sunLonRad)).radiansToDegrees

        return (ra, dec)
    }

    // MARK: - Moon Position (simplified Meeus)

    /// Returns Moon RA/Dec in degrees for a given Julian Date.
    /// Uses the principal terms from Meeus Ch. 47.
    static func moonEquatorial(jd: Double) -> (ra: Double, dec: Double) {
        let T = (jd - 2451545.0) / 36525.0

        // Fundamental arguments (degrees)
        let Lp = (218.3164477 + 481267.88123421 * T
                   - 0.0015786 * T * T
                   + T * T * T / 538841.0
                   - T * T * T * T / 65194000.0).mod(360)  // Mean longitude
        let D = (297.8501921 + 445267.1114034 * T
                  - 0.0018819 * T * T
                  + T * T * T / 545868.0
                  - T * T * T * T / 113065000.0).mod(360)   // Mean elongation
        let M = (357.5291092 + 35999.0502909 * T
                  - 0.0001536 * T * T
                  + T * T * T / 24490000.0).mod(360)         // Sun mean anomaly
        let Mp = (134.9633964 + 477198.8675055 * T
                   + 0.0087414 * T * T
                   + T * T * T / 69699.0
                   - T * T * T * T / 14712000.0).mod(360)    // Moon mean anomaly
        let F = (93.2720950 + 483202.0175233 * T
                  - 0.0036539 * T * T
                  - T * T * T / 3526000.0
                  + T * T * T * T / 863310000.0).mod(360)    // Argument of latitude

        // Additional arguments
        let A1 = (119.75 + 131.849 * T).mod(360)
        let A2 = (53.09 + 479264.290 * T).mod(360)
        let A3 = (313.45 + 481266.484 * T).mod(360)

        let Drad = D.degreesToRadians
        let Mrad = M.degreesToRadians
        let Mprad = Mp.degreesToRadians
        let Frad = F.degreesToRadians
        let A1rad = A1.degreesToRadians
        let A2rad = A2.degreesToRadians
        let A3rad = A3.degreesToRadians

        // Eccentricity correction
        let E = 1.0 - 0.002516 * T - 0.0000074 * T * T
        let E2 = E * E

        // Sum for longitude (principal terms, in units of 0.000001 degrees)
        var sumL: Double = 0
        // (D, M, Mp, F, coefficient)
        let lonTerms: [(Double, Double, Double, Double, Double)] = [
            (0, 0, 1, 0, 6288774),
            (2, 0, -1, 0, 1274027),
            (2, 0, 0, 0, 658314),
            (0, 0, 2, 0, 213618),
            (0, 1, 0, 0, -185116),
            (0, 0, 0, 2, -114332),
            (2, 0, -2, 0, 58793),
            (2, -1, -1, 0, 57066),
            (2, 0, 1, 0, 53322),
            (2, -1, 0, 0, 45758),
            (0, 1, -1, 0, -40923),
            (1, 0, 0, 0, -34720),
            (0, 1, 1, 0, -30383),
            (2, 0, 0, -2, 15327),
            (0, 0, 1, 2, -12528),
            (0, 0, 1, -2, 10980),
            (4, 0, -1, 0, 10675),
            (0, 0, 3, 0, 10034),
            (4, 0, -2, 0, 8548),
            (2, 1, -1, 0, -7888),
            (2, 1, 0, 0, -6766),
            (1, 0, -1, 0, -5163),
            (1, 1, 0, 0, 4987),
            (2, -1, 1, 0, 4036),
            (2, 0, 2, 0, 3994),
            (4, 0, 0, 0, 3861),
            (2, 0, -3, 0, 3665),
            (0, 1, -2, 0, -2689),
            (2, 0, -1, 2, -2602),
            (2, -1, -2, 0, 2390),
            (1, 0, 1, 0, -2348),
            (2, -2, 0, 0, 2236),
            (0, 1, 2, 0, -2120),
            (0, 2, 0, 0, -2069),
            (2, -2, -1, 0, 2048),
            (2, 0, 1, -2, -1773),
            (2, 0, 0, 2, -1595),
            (4, -1, -1, 0, 1215),
            (0, 0, 2, 2, -1110),
            (3, 0, -1, 0, -892),
            (2, 1, 1, 0, -810),
            (4, -1, -2, 0, 759),
            (0, 2, -1, 0, -713),
            (2, 2, -1, 0, -700),
            (2, 1, -2, 0, 691),
            (2, -1, 0, -2, 596),
            (4, 0, 1, 0, 549),
            (0, 0, 4, 0, 537),
            (4, -1, 0, 0, 520),
            (1, 0, -2, 0, -487),
        ]

        for term in lonTerms {
            let arg = term.0 * Drad + term.1 * Mrad + term.2 * Mprad + term.3 * Frad
            var coeff = term.4
            // Apply eccentricity correction for terms involving M
            if abs(term.1) == 1 { coeff *= E }
            else if abs(term.1) == 2 { coeff *= E2 }
            sumL += coeff * sin(arg)
        }

        // Additional corrections to longitude
        sumL += 3958.0 * sin(A1rad)
            + 1962.0 * sin((Lp - F).degreesToRadians)
            + 318.0 * sin(A2rad)

        // Sum for latitude
        var sumB: Double = 0
        let latTerms: [(Double, Double, Double, Double, Double)] = [
            (0, 0, 0, 1, 5128122),
            (0, 0, 1, 1, 280602),
            (0, 0, 1, -1, 277693),
            (2, 0, 0, -1, 173237),
            (2, 0, -1, 1, 55413),
            (2, 0, -1, -1, 46271),
            (2, 0, 0, 1, 32573),
            (0, 0, 2, 1, 17198),
            (2, 0, 1, -1, 9266),
            (0, 0, 2, -1, 8822),
            (2, -1, 0, -1, 8216),
            (2, 0, -2, -1, 4324),
            (2, 0, 1, 1, 4200),
            (2, 1, 0, -1, -3359),
            (2, -1, -1, 1, 2463),
            (2, -1, 0, 1, 2211),
            (2, -1, -1, -1, 2065),
            (0, 1, -1, -1, -1870),
            (4, 0, -1, -1, 1828),
            (0, 1, 0, 1, -1794),
            (0, 0, 0, 3, -1749),
            (0, 1, -1, 1, -1565),
            (1, 0, 0, 1, -1491),
            (0, 1, 1, 1, -1475),
            (0, 1, 1, -1, -1410),
            (0, 1, 0, -1, -1344),
            (1, 0, 0, -1, -1335),
            (0, 0, 3, 1, 1107),
            (4, 0, 0, -1, 1021),
            (4, 0, -1, 1, 833),
        ]

        for term in latTerms {
            let arg = term.0 * Drad + term.1 * Mrad + term.2 * Mprad + term.3 * Frad
            var coeff = term.4
            if abs(term.1) == 1 { coeff *= E }
            else if abs(term.1) == 2 { coeff *= E2 }
            sumB += coeff * sin(arg)
        }

        // Additional corrections to latitude
        sumB += -2235.0 * sin(Lp.degreesToRadians)
            + 382.0 * sin(A3rad)
            + 175.0 * sin((A1 - F).degreesToRadians)
            + 175.0 * sin((A1 + F).degreesToRadians)
            + 127.0 * sin((Lp - Mp).degreesToRadians)
            - 115.0 * sin((Lp + Mp).degreesToRadians)

        // Ecliptic coordinates (degrees)
        let moonLon = (Lp + sumL / 1000000.0).mod(360)
        let moonLat = sumB / 1000000.0

        // Convert ecliptic to equatorial
        let omega = (125.04 - 1934.136 * T).degreesToRadians
        let epsilon = (23.4393 - 0.01300 * T + 0.00256 * cos(omega)).degreesToRadians

        let lonRad = moonLon.degreesToRadians
        let latRad = moonLat.degreesToRadians

        let ra = atan2(
            sin(lonRad) * cos(epsilon) - tan(latRad) * sin(epsilon),
            cos(lonRad)
        ).radiansToDegrees.mod(360)

        let dec = asin(
            sin(latRad) * cos(epsilon) + cos(latRad) * sin(epsilon) * sin(lonRad)
        ).radiansToDegrees

        return (ra, dec)
    }

    // MARK: - Coordinate Transforms

    /// Convert equatorial (RA/Dec) to horizontal (Alt/Az) coordinates.
    static func equatorialToAltAz(
        ra: Double, dec: Double,
        jd: Double, lat: Double, lon: Double
    ) -> (alt: Double, az: Double) {
        let gmst = greenwichMeanSiderealTime(jd: jd)
        let lst = (gmst + lon).mod(360) // Local sidereal time
        let ha = (lst - ra).mod(360)     // Hour angle

        let haRad = ha.degreesToRadians
        let decRad = dec.degreesToRadians
        let latRad = lat.degreesToRadians

        let sinAlt = sin(decRad) * sin(latRad) + cos(decRad) * cos(latRad) * cos(haRad)
        let alt = asin(sinAlt).radiansToDegrees

        let cosAz = (sin(decRad) - sin(alt.degreesToRadians) * sin(latRad))
            / (cos(alt.degreesToRadians) * cos(latRad))
        var az = acos(max(-1, min(1, cosAz))).radiansToDegrees
        if sin(haRad) > 0 { az = 360.0 - az }

        return (alt, az)
    }

    /// Greenwich Mean Sidereal Time in degrees for a Julian Date.
    static func greenwichMeanSiderealTime(jd: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0
        var gmst = 280.46061837
            + 360.98564736629 * (jd - 2451545.0)
            + 0.000387933 * T * T
            - T * T * T / 38710000.0
        gmst = gmst.mod(360)
        return gmst
    }

    // MARK: - Quick Visibility Check

    /// Checks if a target is above minAlt at midnight for a given date.
    /// Returns true if the target reaches above the given altitude during nighttime hours.
    /// Lightweight — checks altitude at 9 PM, midnight, and 3 AM local time.
    static func isTargetUpAtNight(
        targetRA: Double, targetDec: Double,
        latitude: Double, longitude: Double,
        date: Date, timezone: String,
        minAlt: Double = 15.0
    ) -> Bool {
        let tz = TimeZone(identifier: timezone) ?? .current
        let calendar = Calendar.current
        var comps = calendar.dateComponents(in: tz, from: date)

        for hour in [21, 0, 3] {
            comps.hour = hour
            comps.minute = 0
            comps.second = 0
            if hour < 12 {
                // Next day for post-midnight hours
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                    comps = calendar.dateComponents(in: tz, from: nextDay)
                    comps.hour = hour
                    comps.minute = 0
                    comps.second = 0
                }
            }
            guard let checkDate = calendar.date(from: comps) else { continue }
            let jd = julianDate(from: checkDate)
            let altAz = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: jd, lat: latitude, lon: longitude)
            if altAz.alt >= minAlt { return true }
        }
        return false
    }

    /// Pre-computed reference values for batch visibility calculations.
    /// Create once, pass to `firstVisibleInfo` for each target.
    struct VisibilityRef {
        let refMidnight: Date    // next local midnight
        let refJD: Double        // Julian Date at refMidnight
        let refLST: Double       // Local Sidereal Time at refMidnight (degrees)
        let latRad: Double       // latitude in radians
        let latitude: Double
        let longitude: Double
        let fmt: DateFormatter

        init(latitude: Double, longitude: Double, timezone: String) {
            let tz = TimeZone(identifier: timezone) ?? .current
            var cal = Calendar.current
            cal.timeZone = tz
            let today = Date()
            let todayMidnight = cal.startOfDay(for: today)
            self.refMidnight = todayMidnight.addingTimeInterval(86400)
            self.refJD = AstronomyEngine.julianDate(from: refMidnight)
            self.refLST = (AstronomyEngine.greenwichMeanSiderealTime(jd: refJD) + longitude).mod(360)
            self.latRad = latitude.degreesToRadians
            self.latitude = latitude
            self.longitude = longitude
            self.fmt = DateFormatter()
            self.fmt.dateFormat = "MMM d"
        }
    }

    /// Returns (label, daysUntilVisible) for a target using pure geometric calculation.
    /// Pass a shared `VisibilityRef` for batch calls (avoids repeated Calendar/TZ setup).
    static func firstVisibleInfo(
        targetRA: Double, targetDec: Double,
        ref: VisibilityRef,
        minAlt: Double = 15.0
    ) -> (label: String, daysAway: Int) {
        let decRad = targetDec.degreesToRadians
        let minAltRad = minAlt.degreesToRadians

        // Max altitude this target ever reaches at this latitude
        let maxAlt = 90.0 - abs(ref.latitude - targetDec)

        // If target never reaches minAlt, find its peak date
        if maxAlt < minAlt {
            let raOffset = (targetRA - ref.refLST).mod(360)
            let daysToTransit = Int(round(raOffset / 0.9856))
            let transitDate = ref.refMidnight.addingTimeInterval(Double(daysToTransit) * 86400)
            let transitJD = ref.refJD + Double(daysToTransit)
            let altAz = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: transitJD, lat: ref.latitude, lon: ref.longitude)
            return ("Peak \(String(format: "%.0f", altAz.alt))° on \(ref.fmt.string(from: transitDate))", -1)
        }

        // Hour angle limit: how far from meridian the target can be while still above minAlt
        let cosHALimit = (sin(minAltRad) - sin(decRad) * sin(ref.latRad)) / (cos(decRad) * cos(ref.latRad))
        let haLimitDeg: Double
        if cosHALimit <= -1 {
            haLimitDeg = 180.0 // circumpolar above minAlt
        } else if cosHALimit >= 1 {
            haLimitDeg = 0.0
        } else {
            haLimitDeg = acos(cosHALimit).radiansToDegrees
        }

        // Days the target is above minAlt centered on transit date
        // Add 45° margin for nighttime hours (9PM/3AM, not just midnight)
        let visibleHalfWindowDays = (haLimitDeg + 45.0) / 0.9856

        // Midnight transit: when HA=0 at midnight → LST = RA
        let raOffset = (targetRA - ref.refLST).mod(360)
        let daysToTransit = Int(round(raOffset / 0.9856))

        // First visible ≈ transit date minus half the visible window
        let firstVisibleDay = max(0, daysToTransit - Int(visibleHalfWindowDays))

        // Check if it's visible now
        if firstVisibleDay <= 0 {
            // Quick altitude checks: midnight, 9 PM, 3 AM
            let altMid = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: ref.refJD, lat: ref.latitude, lon: ref.longitude).alt
            if altMid >= minAlt { return ("Up now", 0) }
            let alt9pm = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: ref.refJD - 3.0/24.0, lat: ref.latitude, lon: ref.longitude).alt
            if alt9pm >= minAlt { return ("Up now", 0) }
            let alt3am = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: ref.refJD + 3.0/24.0, lat: ref.latitude, lon: ref.longitude).alt
            if alt3am >= minAlt { return ("Up now", 0) }
        }

        // Return the estimated first-visible date
        let resultDay = max(1, firstVisibleDay)
        let resultDate = ref.refMidnight.addingTimeInterval(Double(resultDay) * 86400)
        return ("Up \(ref.fmt.string(from: resultDate))", resultDay)
    }

    /// Convenience wrapper for single-target calls (used by computeVisibilityInfo fallback).
    static func firstVisibleInfo(
        targetRA: Double, targetDec: Double,
        latitude: Double, longitude: Double,
        timezone: String,
        minAlt: Double = 15.0
    ) -> (label: String, daysAway: Int) {
        let ref = VisibilityRef(latitude: latitude, longitude: longitude, timezone: timezone)
        return firstVisibleInfo(targetRA: targetRA, targetDec: targetDec, ref: ref, minAlt: minAlt)
    }

    // MARK: - Angular Separation

    /// Angular separation between two points in equatorial coordinates (degrees).
    static func angularSeparationEquatorial(
        ra1: Double, dec1: Double,
        ra2: Double, dec2: Double
    ) -> Double {
        let ra1r = ra1.degreesToRadians
        let dec1r = dec1.degreesToRadians
        let ra2r = ra2.degreesToRadians
        let dec2r = dec2.degreesToRadians

        let cosD = sin(dec1r) * sin(dec2r) + cos(dec1r) * cos(dec2r) * cos(ra1r - ra2r)
        return acos(max(-1, min(1, cosD))).radiansToDegrees
    }

    /// Angular separation between two alt/az positions (degrees).
    static func angularSeparationAltAz(
        alt1: Double, az1: Double,
        alt2: Double, az2: Double
    ) -> Double {
        let alt1r = alt1.degreesToRadians
        let alt2r = alt2.degreesToRadians
        let daz = (az1 - az2).degreesToRadians

        let cosD = sin(alt1r) * sin(alt2r) + cos(alt1r) * cos(alt2r) * cos(daz)
        return acos(max(-1, min(1, cosD))).radiansToDegrees
    }

    // MARK: - Imaging Window

    /// Calculate the imaging window from observation time until target drops below 30 deg
    /// or 1 hour before sunrise.
    static func calculateImagingWindow(
        targetRA: Double,
        targetDec: Double,
        latitude: Double,
        longitude: Double,
        obsDate: Date,
        tz: TimeZone,
        calendar: Calendar,
        altitudeThreshold: Double = 30.0
    ) -> ImagingWindow {
        // Check target altitude at observation time
        let jdObs = julianDate(from: obsDate)
        let targetStart = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: jdObs, lat: latitude, lon: longitude)

        if targetStart.alt < altitudeThreshold {
            return ImagingWindow(durationHours: 0, startTime: obsDate, endTime: nil)
        }

        // Find approximate sunrise the next morning
        let sunriseApprox = calendar.date(byAdding: .hour, value: 10, to: obsDate)!
        let sunriseTime = findSunrise(near: sunriseApprox, latitude: latitude, longitude: longitude)
        let cutoffTime = sunriseTime.addingTimeInterval(-3600) // 1 hour before sunrise

        // Walk forward in 15-minute steps
        var currentTime = obsDate
        var endTime = cutoffTime

        while currentTime < cutoffTime {
            currentTime = currentTime.addingTimeInterval(15 * 60)
            if currentTime >= cutoffTime {
                endTime = cutoffTime
                break
            }
            let jd = julianDate(from: currentTime)
            let altAz = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: jd, lat: latitude, lon: longitude)
            if altAz.alt < altitudeThreshold {
                endTime = currentTime
                break
            }
        }

        let duration = endTime.timeIntervalSince(obsDate) / 3600.0
        return ImagingWindow(durationHours: (duration * 10).rounded() / 10, startTime: obsDate, endTime: endTime)
    }

    /// Find sunset time near an approximate date by checking when sun altitude drops below ~0.
    static func findSunset(near approx: Date, latitude: Double, longitude: Double) -> Date {
        var lastAbove: Date = approx
        for minuteOffset in stride(from: -240, through: 120, by: 5) {
            let testDate = approx.addingTimeInterval(Double(minuteOffset) * 60)
            let jd = julianDate(from: testDate)
            let sunEq = sunEquatorial(jd: jd)
            let sunAltAz = equatorialToAltAz(ra: sunEq.ra, dec: sunEq.dec, jd: jd, lat: latitude, lon: longitude)
            if sunAltAz.alt > -0.5 {
                lastAbove = testDate
            } else if lastAbove != approx {
                return testDate
            }
        }
        return lastAbove
    }

    /// Interpolated minimum altitude for a given azimuth using 8-cardinal values.
    /// `minAltitudes` is [N, NE, E, SE, S, SW, W, NW] (8 values at 0°, 45°, ..., 315°).
    static func interpolatedMinAltitude(forAzimuth azimuth: Double, minAltitudes: [Double]) -> Double {
        guard minAltitudes.count == 8 else { return minAltitudes.first ?? 30 }
        let az = azimuth.mod(360)
        let sector = az / 45.0
        let lower = Int(sector) % 8
        let upper = (lower + 1) % 8
        let blend = sector - Double(Int(sector))
        return minAltitudes[lower] * (1.0 - blend) + minAltitudes[upper] * blend
    }

    /// Find when the target is above the directional minimum altitude during the darkness window.
    static func findTargetVisibility(
        targetRA: Double, targetDec: Double,
        latitude: Double, longitude: Double,
        darknessStart: Date, darknessEnd: Date,
        minAltitudes: [Double]
    ) -> TargetVisibilitySpan? {
        let stepSeconds: TimeInterval = 10 * 60  // 10-minute steps
        let totalSeconds = darknessEnd.timeIntervalSince(darknessStart)
        guard totalSeconds > 0 else { return nil }

        var riseTime: Date? = nil
        var setTime: Date? = nil
        var riseAz: Double = 0
        var setAz: Double = 0
        var riseMinAltVal: Double = 0
        var setMinAltVal: Double = 0
        var wasAbove = false
        var wasAlreadyUp = false

        // Check darknessStart
        let jdStart = julianDate(from: darknessStart)
        let startAltAz = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: jdStart, lat: latitude, lon: longitude)
        let startMinAlt = interpolatedMinAltitude(forAzimuth: startAltAz.az, minAltitudes: minAltitudes)
        if startAltAz.alt >= startMinAlt {
            riseTime = darknessStart
            riseAz = startAltAz.az
            riseMinAltVal = startMinAlt
            wasAbove = true
            wasAlreadyUp = true
        }

        // Walk through the night
        var t: TimeInterval = stepSeconds
        while t <= totalSeconds {
            let checkTime = darknessStart.addingTimeInterval(t)
            let jd = julianDate(from: checkTime)
            let altAz = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: jd, lat: latitude, lon: longitude)
            let minAlt = interpolatedMinAltitude(forAzimuth: altAz.az, minAltitudes: minAltitudes)
            let isAbove = altAz.alt >= minAlt

            if isAbove && !wasAbove {
                riseTime = checkTime
                riseAz = altAz.az
                riseMinAltVal = minAlt
            } else if !isAbove && wasAbove {
                setTime = checkTime
                setAz = altAz.az
                setMinAltVal = minAlt
                break
            }
            wasAbove = isAbove
            t += stepSeconds
        }

        guard let rise = riseTime else { return nil }
        let set = setTime ?? darknessEnd

        // If target was still up at darknessEnd, capture the final azimuth/minAlt
        if setTime == nil {
            let jdEnd = julianDate(from: darknessEnd)
            let endAltAz = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: jdEnd, lat: latitude, lon: longitude)
            setAz = endAltAz.az
            setMinAltVal = interpolatedMinAltitude(forAzimuth: endAltAz.az, minAltitudes: minAltitudes)
        }

        let riseOffset = rise.timeIntervalSince(darknessStart) / 3600.0
        let setOffset = set.timeIntervalSince(darknessStart) / 3600.0
        let duration = set.timeIntervalSince(rise) / 3600.0

        return TargetVisibilitySpan(
            riseTime: rise,
            setTime: set,
            durationHours: (duration * 10).rounded() / 10,
            riseOffsetHours: (riseOffset * 10).rounded() / 10,
            setOffsetHours: (setOffset * 10).rounded() / 10,
            riseAzimuth: riseAz,
            setAzimuth: setAz,
            riseMinAlt: riseMinAltVal,
            setMinAlt: setMinAltVal,
            alreadyUpAtStart: wasAlreadyUp,
            stillUpAtEnd: setTime == nil
        )
    }

    /// Find when the moon is above the horizon during the darkness window.
    /// Unlike deep-sky targets, the moon moves ~0.5°/hr, so we must recalculate
    /// its RA/Dec at each timestep.
    static func findMoonVisibility(
        latitude: Double, longitude: Double,
        darknessStart: Date, darknessEnd: Date
    ) -> TargetVisibilitySpan? {
        let stepSeconds: TimeInterval = 10 * 60  // 10-minute steps
        let totalSeconds = darknessEnd.timeIntervalSince(darknessStart)
        guard totalSeconds > 0 else { return nil }

        var riseTime: Date? = nil
        var setTime: Date? = nil
        var wasAbove = false

        // Check darknessStart
        let jdStart = julianDate(from: darknessStart)
        let moonEqStart = moonEquatorial(jd: jdStart)
        let startAltAz = equatorialToAltAz(
            ra: moonEqStart.ra, dec: moonEqStart.dec,
            jd: jdStart, lat: latitude, lon: longitude
        )
        if startAltAz.alt >= 0 {
            riseTime = darknessStart
            wasAbove = true
        }

        // Walk through the night
        var t: TimeInterval = stepSeconds
        while t <= totalSeconds {
            let checkTime = darknessStart.addingTimeInterval(t)
            let jd = julianDate(from: checkTime)
            let moonEq = moonEquatorial(jd: jd)
            let altAz = equatorialToAltAz(
                ra: moonEq.ra, dec: moonEq.dec,
                jd: jd, lat: latitude, lon: longitude
            )
            let isAbove = altAz.alt >= 0

            if isAbove && !wasAbove {
                riseTime = checkTime
            } else if !isAbove && wasAbove {
                setTime = checkTime
                break
            }
            wasAbove = isAbove
            t += stepSeconds
        }

        guard let rise = riseTime else { return nil }
        let set = setTime ?? (wasAbove ? darknessEnd : rise)

        let riseOffset = rise.timeIntervalSince(darknessStart) / 3600.0
        let setOffset = set.timeIntervalSince(darknessStart) / 3600.0
        let duration = set.timeIntervalSince(rise) / 3600.0

        guard duration > 0 else { return nil }

        return TargetVisibilitySpan(
            riseTime: rise,
            setTime: set,
            durationHours: (duration * 10).rounded() / 10,
            riseOffsetHours: (riseOffset * 10).rounded() / 10,
            setOffsetHours: (setOffset * 10).rounded() / 10,
            riseAzimuth: 0,
            setAzimuth: 0,
            riseMinAlt: 0,
            setMinAlt: 0,
            alreadyUpAtStart: false,
            stillUpAtEnd: false
        )
    }

    /// Compute moon altitude at regular intervals throughout the darkness window.
    /// Used for rendering the moon-glow background gradient in the bar chart.
    static func computeMoonAltitudeProfile(
        latitude: Double, longitude: Double,
        darknessStart: Date, darknessEnd: Date
    ) -> [MoonAltitudeSample] {
        let stepSeconds: TimeInterval = 20 * 60  // 20-minute steps
        let totalSeconds = darknessEnd.timeIntervalSince(darknessStart)
        guard totalSeconds > 0 else { return [] }

        var samples: [MoonAltitudeSample] = []
        var t: TimeInterval = 0
        while t <= totalSeconds {
            let time = darknessStart.addingTimeInterval(t)
            let jd = julianDate(from: time)
            let moonEq = moonEquatorial(jd: jd)
            let altAz = equatorialToAltAz(
                ra: moonEq.ra, dec: moonEq.dec,
                jd: jd, lat: latitude, lon: longitude
            )
            samples.append(MoonAltitudeSample(time: time, altitude: altAz.alt))
            t += stepSeconds
        }
        return samples
    }

    /// Analyze how much of a target's visibility overlaps with moon above/below horizon.
    /// Returns hours of moon-down visibility, hours of moon-up visibility, and average separation during moon-up.
    static func analyzeMoonOverlap(
        targetRA: Double, targetDec: Double,
        latitude: Double, longitude: Double,
        targetVisibility: TargetVisibilitySpan?,
        moonVisibility: TargetVisibilitySpan?,
        darknessStart: Date, darknessEnd: Date
    ) -> (hoursMoonDown: Double, hoursMoonUp: Double, avgSeparationMoonUp: Double?) {
        guard let targetVis = targetVisibility else {
            return (0, 0, nil)
        }

        // If moon never rises, all target visibility is moon-down
        guard let moonVis = moonVisibility else {
            return (targetVis.durationHours, 0, nil)
        }

        let stepMinutes: TimeInterval = 10 * 60
        var moonDownMinutes: Double = 0
        var moonUpMinutes: Double = 0
        var separations: [Double] = []

        var t = targetVis.riseTime
        while t < targetVis.setTime {
            let isMoonUp = t >= moonVis.riseTime && t < moonVis.setTime

            if isMoonUp {
                moonUpMinutes += 10
                // Calculate actual separation at this moment
                let jd = julianDate(from: t)
                let moonEq = moonEquatorial(jd: jd)
                let moonAltAz = equatorialToAltAz(ra: moonEq.ra, dec: moonEq.dec, jd: jd, lat: latitude, lon: longitude)
                let targetAltAz = equatorialToAltAz(ra: targetRA, dec: targetDec, jd: jd, lat: latitude, lon: longitude)
                let sep = angularSeparationAltAz(
                    alt1: moonAltAz.alt, az1: moonAltAz.az,
                    alt2: targetAltAz.alt, az2: targetAltAz.az
                )
                separations.append(sep)
            } else {
                moonDownMinutes += 10
            }

            t = t.addingTimeInterval(stepMinutes)
        }

        let hoursDown = (moonDownMinutes / 60.0 * 10).rounded() / 10
        let hoursUp = (moonUpMinutes / 60.0 * 10).rounded() / 10
        let avgSep = separations.isEmpty ? nil : (separations.reduce(0, +) / Double(separations.count) * 10).rounded() / 10

        return (hoursDown, hoursUp, avgSep)
    }

    /// Find sunrise time near an approximate date by checking when sun altitude crosses 0.
    static func findSunrise(near approx: Date, latitude: Double, longitude: Double) -> Date {
        // Search from 2 hours before to 4 hours after the approximation
        for minuteOffset in stride(from: -120, through: 240, by: 5) {
            let testDate = approx.addingTimeInterval(Double(minuteOffset) * 60)
            let jd = julianDate(from: testDate)
            let sunEq = sunEquatorial(jd: jd)
            let sunAltAz = equatorialToAltAz(ra: sunEq.ra, dec: sunEq.dec, jd: jd, lat: latitude, lon: longitude)
            if sunAltAz.alt > -0.5 {
                return testDate
            }
        }
        return approx
    }
}

// MARK: - Helpers

extension Double {
    nonisolated var degreesToRadians: Double { self * .pi / 180.0 }
    nonisolated var radiansToDegrees: Double { self * 180.0 / .pi }

    /// Positive modulo (always returns value in [0, m))
    nonisolated func mod(_ m: Double) -> Double {
        let result = self.truncatingRemainder(dividingBy: m)
        return result >= 0 ? result : result + m
    }
}
