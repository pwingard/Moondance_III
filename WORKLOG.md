# Moondance-iOS Work Log

## Project Overview
Moondance-iOS is an astrophotography planning app. Users pick a location + deep sky target, and it calculates moon altitude, target altitude, angular separation, moon phase, and imaging windows over a 30-day range. Results are displayed in a Swift Charts view with landscape fullscreen mode.

## Architecture
- `Moondance_iOSApp.swift` — App entry point, launches ContentView
- `ContentView.swift` — Main UI: portrait form + landscape fullscreen chart, settings persistence via @AppStorage, calculation trigger, CSV/chart export
- `Views/ChartView.swift` — Swift Charts view: moon alt (blue line), target alt (white line), angular separation (orange dashed), moon phase-colored point markers, horizontal reference lines, vertical phase milestone lines, tap tooltip
- `Views/SettingsFormView.swift` — Form for picking location, target, date, time, custom coords
- `Views/SummaryView.swift` — Text summary/recommendations below chart
- `Models/Location.swift` — Location struct (id, name, lat, lon, elevation, timezone)
- `Models/Target.swift` — Target struct (id, name, type, ra, dec, magnitude, size)
- `Models/CalculationResult.swift` — DayResult, ImagingWindow, CalculationResult structs
- `Models/DataManager.swift` — Singleton that loads locations.json and targets.json from bundle
- `Services/AstronomyEngine.swift` — Pure-Swift Meeus-based astronomy calculations (moon/sun position, alt/az, angular separation, imaging windows)
- `Services/LocationService.swift` — CoreLocation wrapper
- `Data/` — JSON data files (locations.json, targets.json)

## 2026-02-04 — Session 1 (crashed)

### What was done
- Fixed chart clipping (left/bottom) in landscape: safe area insets, increased height deduction
- Added date range to chart title: `(MMM d – MMM d)`
- Added moon phase annotations — went through several iterations:
  - Emoji labels → removed, switched to small white text
  - Fixed 1st/3rd quarter waxing/waning detection
  - Fixed doubled labels by picking single best day per phase (global min/max)
- Made center/horizon line bolder (2pt, 60% opacity)
- Balanced Y-scale: symmetric around 0° based on data extent, rounded to 30°
- Dynamic altitude/separation tick values
- Added dashed reference lines at ±30°, ±60°, ±90°
- Reduced calculation to 30 days
- Landscape padding accounts for all four safe area insets
- Tried embedding phase labels in x-axis date labels — broke the chart layout
- Session ended with API error before fix could be applied

### User's last request before crash
"go back to the way the dates were before and use this as the way to show the peaks etc" — wanted simple date labels on x-axis + vertical dashed lines at phase milestones

## 2026-02-04 — Session 2 (current)

### What was done
- Reverted x-axis to simple evenly-spaced date labels (~6 labels)
- Added vertical dashed RuleMark lines at each moon phase milestone (New, Full, 1st Qtr, 3rd Qtr)
- Phase labels positioned via `.annotation(position: .top)` — labels overlapped when phases were close together
- Tried `.overlay` with rotated text and staggered offsets — still looked bad
- Rewrote ChartView to fix performance: replaced 29 separate separation series (`Sep-0` through `Sep-28`) with a single "Separation" series in orange — this was causing the slow chart rendering
- Moved phase labels into `chartOverlay` using `proxy.position(forX:)` for screen-coordinate positioning
- Also fixed deprecated `plotAreaFrame` → `plotFrame`
- Updated legend to show single orange circle for separation

### Known Issues / What Needs Fixing
1. **Phase label positioning** — labels in chartOverlay need testing; the offset math (`plotFrame.origin.x + xPos - 14`) may not be right for all screen sizes
2. **Separation line is now single color (orange)** — lost the per-segment green/yellow/red coloring. The point markers still have color coding. If per-segment coloring is wanted back, need a performant approach (NOT 29 separate series)
3. **Y-axis labels** — in the screenshot from this session, the left y-axis was showing repeated "0°" values. May be a rendering artifact or tick value issue. The tick logic looks correct in code (-90 to 90 by 30) but needs verification

### Current State of ChartView.swift
- Y-scale: symmetric, dynamic (ceil to nearest 30°)
- Center line: bold white 2pt at 0°
- Dashed horizontal reference lines at ±30, ±60, ±90
- Vertical dashed lines at moon phase milestones (no annotation labels inside Chart — labels via chartOverlay)
- Separation: single orange dashed line + colored point markers
- X-axis: ~6 evenly spaced date labels, simple text
- Tooltip on tap with 5s auto-dismiss
- Imaging windows toggle

### Files Modified This Session
- `Views/ChartView.swift` — full rewrite of chart marks, phase lines, separation series, chartOverlay labels

### What the User Wants Next
- Vertical dashed lines at New, 1st Quarter, Full, 3rd Quarter moon phases
- Each line labeled with the phase name (e.g. "New", "Full", "1st Qtr", "3rd Qtr")
- Simple date labels on x-axis (not combined with phase info)
- Labels should not overlap even when phases are close together
- Chart should render fast (no lag)
- The chart was looking good before the phase label experiments broke it — goal is to get back to that quality level with the addition of clean phase milestone indicators

## 2026-02-06 — Session 3 (App Store prep)

### What was done
- Preparing app for App Store / TestFlight submission
- Identified 4 critical blockers and addressed 3 of them:

1. **PrivacyInfo.xcprivacy** ✅ — Created and added to project. Declares:
   - No tracking
   - Coarse location collected for app functionality (not linked to identity)
   - UserDefaults accessed (reason CA92.1: app reads/writes its own settings)
   - User added file to Xcode target via Project Navigator

2. **NSLocationWhenInUseUsageDescription** ✅ — Already present in build settings (both Debug and Release configs)

3. **Hardcoded email in FeedbackView** ✅ — Changed from `TEMPPFW@gmail.com` to `moondance.support@pfwingard.com`
   - Set up email forwarding in Namecheap: `moondance.support@pfwingard.com` → `temppfw@gmail.com`
   - Switched Namecheap Mail Settings from "Private Email" to "Email Forwarding"
   - MX records confirmed propagated (eforward1-5.registrar-servers.com)
   - SPF TXT record confirmed
   - **EMAIL NOT YET VERIFIED WORKING** — got "server misconfigured" error when testing. May need a few hours for Namecheap forwarding to fully activate after switching from Private Email mode. Retry later.

4. **Privacy policy** ⏳ — Deferred. Need to create and host at moondance.pfwingard.com. Required for App Store but not for TestFlight beta.

### Additional notes
- User already has web version of Moondance at moondance.pfwingard.com — can host privacy policy there
- Domain registrar: Namecheap (pfwingard.com)
- App version: 0.8, build 1
- Build succeeds on iPhone 17 Pro Max simulator
- Had duplicate PrivacyInfo.xcprivacy (one at project root, one in Moondance-iOS dir) — user should verify only one remains in Xcode target

### Files Modified This Session
- `Moondance-iOS/PrivacyInfo.xcprivacy` — NEW, privacy manifest
- `Views/FeedbackView.swift` — updated recipient email

### Still TODO before App Store submission
- Verify email forwarding works (retry moondance.support@pfwingard.com)
- Create and host privacy policy at moondance.pfwingard.com/privacy
- Prepare App Store metadata (description, keywords, screenshots)
- Delete duplicate PrivacyInfo.xcprivacy at project root if still there
- Test on physical device
