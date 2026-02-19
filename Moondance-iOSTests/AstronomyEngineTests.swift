import Testing
import Foundation
@testable import Moondance_iOS

@Suite("AstronomyEngine")
struct AstronomyEngineTests {

    // MARK: - Julian Date

    @Test func julianDate_J2000() {
        // J2000.0 = Jan 1, 2000 at 12:00:00 UTC = JD 2451545.0
        // Unix epoch offset: (2451545.0 - 2440587.5) * 86400 = 946727935... let's use formula directly
        let j2000Unix: TimeInterval = (2451545.0 - 2440587.5) * 86400.0
        let j2000Date = Date(timeIntervalSince1970: j2000Unix)
        let jd = AstronomyEngine.julianDate(from: j2000Date)
        #expect(abs(jd - 2451545.0) < 0.0001)
    }

    @Test func julianDate_unixEpoch() {
        // Unix epoch (Jan 1, 1970 00:00 UTC) = JD 2440587.5
        let unixEpoch = Date(timeIntervalSince1970: 0)
        let jd = AstronomyEngine.julianDate(from: unixEpoch)
        #expect(abs(jd - 2440587.5) < 0.0001)
    }

    @Test func julianDate_roundTrip() {
        let now = Date()
        let jd = AstronomyEngine.julianDate(from: now)
        let back = AstronomyEngine.dateFromJD(jd)
        #expect(abs(back.timeIntervalSince(now)) < 1.0)  // within 1 second
    }

    @Test func julianDate_isMonotonicallyIncreasing() {
        let d1 = Date(timeIntervalSince1970: 1000000)
        let d2 = Date(timeIntervalSince1970: 2000000)
        #expect(AstronomyEngine.julianDate(from: d1) < AstronomyEngine.julianDate(from: d2))
    }

    // MARK: - Angular Separation

    @Test func angularSeparation_samePoint_isZero() {
        let sep = AstronomyEngine.angularSeparationEquatorial(ra1: 83.82, dec1: -5.39,
                                                               ra2: 83.82, dec2: -5.39)
        #expect(abs(sep) < 0.001)
    }

    @Test func angularSeparation_antipodalPoints_is180() {
        // Two points on opposite sides of the celestial sphere
        let sep = AstronomyEngine.angularSeparationEquatorial(ra1: 0, dec1: 0,
                                                               ra2: 180, dec2: 0)
        #expect(abs(sep - 180.0) < 0.1)
    }

    @Test func angularSeparation_northSouthPole_is180() {
        let sep = AstronomyEngine.angularSeparationEquatorial(ra1: 0, dec1: 90,
                                                               ra2: 0, dec2: -90)
        #expect(abs(sep - 180.0) < 0.1)
    }

    @Test func angularSeparation_isSymmetric() {
        let sep1 = AstronomyEngine.angularSeparationEquatorial(ra1: 83.82, dec1: -5.39,
                                                                ra2: 10.68, dec2: 41.27)
        let sep2 = AstronomyEngine.angularSeparationEquatorial(ra1: 10.68, dec1: 41.27,
                                                                ra2: 83.82, dec2: -5.39)
        #expect(abs(sep1 - sep2) < 0.001)
    }

    @Test func angularSeparation_isNonNegative() {
        let sep = AstronomyEngine.angularSeparationEquatorial(ra1: 100, dec1: 30,
                                                               ra2: 200, dec2: -20)
        #expect(sep >= 0)
    }

    @Test func angularSeparation_isAtMost180() {
        let sep = AstronomyEngine.angularSeparationEquatorial(ra1: 100, dec1: 30,
                                                               ra2: 200, dec2: -20)
        #expect(sep <= 180.01)
    }

    // MARK: - Sun position (sanity checks)

    @Test func sunEquatorial_decNearZeroAtEquinox() {
        // Vernal equinox ~March 20 — sun Dec should be near 0°
        // March 20, 2024 12:00 UTC
        let equinox = Date(timeIntervalSince1970: 1710936000)  // approx
        let jd = AstronomyEngine.julianDate(from: equinox)
        let sun = AstronomyEngine.sunEquatorial(jd: jd)
        #expect(abs(sun.dec) < 2.0, "Sun Dec at vernal equinox should be near 0°, got \(sun.dec)°")
    }

    @Test func sunEquatorial_decNearMinusAt_DecSolstice() {
        // Dec solstice — sun Dec near -23.4°
        // Dec 21, 2024 12:00 UTC
        let solstice = Date(timeIntervalSince1970: 1734782400)  // approx
        let jd = AstronomyEngine.julianDate(from: solstice)
        let sun = AstronomyEngine.sunEquatorial(jd: jd)
        #expect(sun.dec < -20.0, "Sun Dec at Dec solstice should be around -23.4°, got \(sun.dec)°")
    }

    @Test func sunEquatorial_raIsInValidRange() {
        let jd = AstronomyEngine.julianDate(from: Date())
        let sun = AstronomyEngine.sunEquatorial(jd: jd)
        #expect(sun.ra >= 0 && sun.ra < 360)
        #expect(sun.dec >= -90 && sun.dec <= 90)
    }

    // MARK: - Moon position (sanity checks)

    @Test func moonEquatorial_returnsValidRange() {
        let jd = AstronomyEngine.julianDate(from: Date())
        let moon = AstronomyEngine.moonEquatorial(jd: jd)
        #expect(moon.ra >= 0 && moon.ra < 360)
        #expect(moon.dec >= -90 && moon.dec <= 90)
    }

    @Test func moonEquatorial_movesOverTime() {
        // Moon moves ~13°/day — over 7 days should move significantly
        let jd1 = 2451545.0
        let jd2 = jd1 + 7.0
        let m1 = AstronomyEngine.moonEquatorial(jd: jd1)
        let m2 = AstronomyEngine.moonEquatorial(jd: jd2)
        let sep = AstronomyEngine.angularSeparationEquatorial(ra1: m1.ra, dec1: m1.dec,
                                                               ra2: m2.ra, dec2: m2.dec)
        #expect(sep > 50.0, "Moon should move > 50° in 7 days, moved \(sep)°")
    }

    // MARK: - findSunset / findSunrise (integration, Atlanta GA)

    @Test func sunsetAndSunriseAreReasonable_Atlanta() {
        // Atlanta lat 33.75, lon -84.39 — sunset should be between 5 PM and 9 PM UTC in winter
        let tz = TimeZone(identifier: "America/New_York")!
        var cal = Calendar.current
        cal.timeZone = tz
        var comps = DateComponents()
        comps.year = 2026; comps.month = 2; comps.day = 23
        comps.hour = 18; comps.minute = 0
        let approxSunset = cal.date(from: comps)!
        let sunset = AstronomyEngine.findSunset(near: approxSunset, latitude: 33.75, longitude: -84.39)

        // Sunset in Atlanta in Feb should be around 6:15-6:30 PM local = 23:15-23:30 UTC
        let hour = cal.component(.hour, from: sunset)
        #expect(hour >= 17 && hour <= 19, "Sunset hour (local) should be 5–7 PM, got \(hour)")
    }

    @Test func sunriseIsAfterSunset() {
        let tz = TimeZone(identifier: "America/New_York")!
        var cal = Calendar.current; cal.timeZone = tz
        var sc = DateComponents(); sc.year = 2026; sc.month = 2; sc.day = 23; sc.hour = 18
        let approxSunset = cal.date(from: sc)!
        var rc = DateComponents(); rc.year = 2026; rc.month = 2; rc.day = 24; rc.hour = 6
        let approxSunrise = cal.date(from: rc)!

        let sunset = AstronomyEngine.findSunset(near: approxSunset, latitude: 33.75, longitude: -84.39)
        let sunrise = AstronomyEngine.findSunrise(near: approxSunrise, latitude: 33.75, longitude: -84.39)

        #expect(sunrise > sunset, "Sunrise must be after sunset")
        let nightHours = sunrise.timeIntervalSince(sunset) / 3600
        #expect(nightHours > 8 && nightHours < 16, "Night length should be 8–16 hours, got \(nightHours)h")
    }
}
