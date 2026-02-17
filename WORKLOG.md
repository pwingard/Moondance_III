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

### App Store Checklist (updated 2026-02-16)
- ✅ Privacy policy — LIVE at pfwingard.com/privacy (contact: seetheshow87@gmail.com)
- ✅ Email forwarding — resolved (went through multiple iterations)
- ✅ PrivacyInfo.xcprivacy — single copy in Moondance-iOS/ (NOTE: not referenced in pbxproj, may need adding to target)
- ✅ Physical device testing — done
- ⏳ App Store metadata (description, keywords, screenshots) — still needed
- ⏳ PrivacyInfo.xcprivacy may not be in Xcode target (0 references in project.pbxproj)

## 2026-02-14/15 — Sessions 4-5 (Favorites, Wikipedia, Target Picker)

### What was done
- Wikipedia integration: WikipediaService.swift fetches article summaries + images via REST API
- WikipediaImageView.swift: modal sheet showing target info + image from Wikipedia
- FavoritesView.swift: save/load favorite targets, grouped by type, swipe-to-delete
- SearchableTargetPicker.swift: type filter pills, text search, altitude checking, star toggle for favorites, info.circle button, color-coded selection (max 6)
- ContentView.swift: magnitude + info.circle added to main target list, favorites button, Wikipedia sheet integration
- targets.json: added new targets including NGC 2170 (Angel Nebula)
- SuggestionEngine.swift: minor update

### Files Modified
- `ContentView.swift` — target section with mag/info, favorites/wiki sheets
- `Views/SearchableTargetPicker.swift` — full rewrite with filters, favorites, altitude checks
- `Views/FavoritesView.swift` — NEW
- `Views/WikipediaImageView.swift` — NEW
- `Services/WikipediaService.swift` — NEW
- `Services/SuggestionEngine.swift` — minor fix
- `Data/targets.json` — added NGC 2170 + others
- `project.pbxproj` — new file references

### Committed & Pushed
- `b880103` — "Add favorites, Wikipedia integration, enhanced target picker, NGC 2170"

## 2026-02-16 — Session 6 (App Store Registration + Bug Fixes)

### App Store Connect Setup
- Apple Developer account: ACTIVE (Team ID: 87HPY7249P)
- Registered Bundle ID: `com.seetheshow.moondance3` (already in pbxproj)
- Created app in App Store Connect: "Moondance Astro Planner"
- iOS App Version 1.0 — "Prepare for Submission" status
- Still need: screenshots, description, keywords, subtitle

### UI Changes
- Title: "Moondance III" → "Moondance"
- Subtitle: "Long Range Planner & Lunar Sidestepper" → "Astrophotography Planner and Lunar Sidestepper"
- Bottom credit: "See the Show Astro v0.9" → "Moondance Studio 87"
- Added NGC 2170 (Angel Nebula) to targets.json
- Confirmed FavoritesView, WikipediaService, WikipediaImageView build OK (PBXFileSystemSynchronizedRootGroup auto-includes)

### Bugs Fixed
1. ✅ Unselect targets — tap target in Selected section of picker to remove (changed checkmark to X icon)
2. ✅ Wikipedia disambiguation — short/ambiguous names now try "(nebula)" and "(astronomy)" suffixes first; Barnard catalog prioritized
3. ✅ Help '?' button — added to landscape chart top-right (next to '!'), sheet attached to ContentView Group level so it works in both orientations
4. ✅ "Up now" / "Up [date]" visibility labels in search picker — green (up now), yellow (within 3 months), orange (over 3 months), red (never clears min alt). Uses lightweight AstronomyEngine check (9 PM, midnight, 3 AM) scanning up to 365 days
5. ✅ "Request an Object" — email button at bottom of search picker, pre-filled mailto to seetheshow87@gmail.com
6. ✅ Portrait chart detail sheets blank — moved NightBarChartView OUT of Form into plain ScrollView/VStack so sheets can present properly
7. ✅ Swift concurrency warnings (12) — changed Task.detached to Task for SuggestionEngine and MemoryProfiler calls

### Bugs Fixed (Round 2)
1. ✅ Dark nebulas wiki — relaxed WikipediaService to accept text-only articles (no image required)
2. ✅ Sort search list by availability — "Sort by availability" toggle flattens all types into single section sorted by daysAway
3. ✅ NGC 5139 red but others not — switched from hardcoded 15° minAlt to directional min altitude (N/S based on transit direction) using DirectionalAltitudes
4. ✅ "Never clears" text now red — applied `.foregroundColor(.red)` for daysAway == -1
5. ✅ Peak altitude for never-clears — added peakNighttimeAltitude() to show "Peak X° on [date]"

### Performance Fix: Visibility Cache (3 iterations to get right)
- **Problem**: `firstVisibleInfo()` scanned 365 days × 3 time checks per target × 100+ targets. Cache never completed — UI showed no visibility data, sort toggle didn't work.
- **Root cause 1**: Day-by-day scanning was O(n×365) — too slow even on MainActor Task.
- **Attempt 1**: Narrowed search window using LST transit date, but still used `isTargetUpAtNight()` in loops — each call created Calendar/TimeZone/DateComponents. Still too slow.
- **Attempt 2**: Used `calendar.dateComponents(in:from:)` + `calendar.date(from:)` — crashed. DateComponents returned by `dateComponents(in:from:)` carry embedded calendar/timezone that conflict when passed back. Fixed with `cal.startOfDay(for:)` but still slow (Calendar per target).
- **Final fix (working)**: Pure geometric O(1) per target:
  - Created `VisibilityRef` struct — pre-computes Calendar, TimeZone, midnight JD, LST, DateFormatter ONCE for all targets
  - `firstVisibleInfo(ref:)` takes shared ref, does only trig math per target (no Calendar calls in loop)
  - Hour angle limit formula: `cos(HA) = (sin(minAlt) - sin(dec)*sin(lat)) / (cos(dec)*cos(lat))` → gives visible window in days
  - "Up now" check: 3 `equatorialToAltAz` calls (midnight, 9PM, 3AM) — pure trig
  - "Never clears": instant `maxAlt = 90° - |lat - dec|` check, peak date via LST transit
  - Removed `Task { }` wrapper — computation is synchronous, completes in milliseconds
  - Removed `peakNighttimeAltitude()` / `peakNighttimeInfo()` — inlined into `firstVisibleInfo`
- **Result**: Cache builds instantly. Visibility labels and sort toggle working.

### Files Modified This Session (complete list)
- `ContentView.swift` — title "Moondance", subtitle, credit "Moondance Studio 87", '?' help button on landscape chart overlay, .sheet at Group level, portrait layout restructure (chart outside Form), Task.detached→Task
- `Views/SearchableTargetPicker.swift` — unselect by tapping Selected row, visibility labels with color coding, sort by availability toggle, visibility cache with async Task build, directional minAlt, "Request an Object" mailto button
- `Views/NightBarChartView.swift` — moved .sheet modifiers to outer VStack (fixes portrait detail sheets)
- `Services/AstronomyEngine.swift` — added isTargetUpAtNight(), firstVisibleInfo() (rewritten with fast geometric calc), peakNighttimeInfo() (fast LST-based)
- `Services/WikipediaService.swift` — disambiguation suffixes "(nebula)"/"(astronomy)", Barnard catalog priority, relaxed image filter for text-only articles
- `Services/SuggestionEngine.swift` — Sendable conformance, Task.detached→Task
- `Views/SettingsFormView.swift` — Task.detached→Task for MemoryProfiler
- `Data/targets.json` — added NGC 2170 (Angel Nebula)
- `WORKLOG.md` — this file

### App Store Status
- Apple Developer account: ACTIVE (Team ID: 87HPY7249P)
- Bundle ID registered: `com.seetheshow.moondance3`
- App created in App Store Connect: "Moondance Astro Planner"
- Privacy policy LIVE at pfwingard.com/privacy
- Contact email: seetheshow87@gmail.com
- ⏳ Still needed: App Store metadata (description, keywords, screenshots), final build upload
- ⏳ MARKETING_VERSION needs updating from 0.8 to 1.0 before submission

## 2026-02-17 — Session 7 (Bug fixes, categories, bundle ID)

### What was done
1. ✅ **Snake Nebula visibility date fix** — Geometric estimate was off because 45° nighttime margin missed pre-dawn targets. Increased to 75° margin (~5h before/after midnight = 7 PM to 5 AM). Added verification loop that checks estimated date ±7 days with full nighttime hour scan.
2. ✅ **Split Cluster into Open Cluster / Globular Cluster** — Updated all 256 entries in targets.json. 87 globular, 169 open. Now appear as separate filter pills in SearchableTargetPicker.
3. ✅ **"Up now" → "Tonight [time]"** — Changed label to show "Tonight 7 PM", "Tonight 3 AM", etc. Scans 7 PM to 5 AM in 1-hour steps to find first hour target clears minAlt.
4. ✅ **Bundle ID fix** — Changed from `com.seetheshow.moondance3` to `com.pfwingard.moondance` in both Debug and Release configs to match App Store Connect registration.
5. ✅ **Test coordinates provided** — M42 (83.82, -5.39), M31 (10.68, 41.27), M57 (283.40, 33.03), IC 434 (85.24, -2.46)

### Files Modified
- `Services/AstronomyEngine.swift` — firstVisibleInfo: wider nighttime margin, verification loop, findRiseTime() for "Tonight X PM/AM" labels
- `Data/targets.json` — split "Cluster" → "Open Cluster" / "Globular Cluster" (256 entries)
- `Moondance-iOS.xcodeproj/project.pbxproj` — bundle ID → com.pfwingard.moondance

### Commits
- `076a11d` — "Fix visibility cache, bug fixes, App Store prep" (session 6 work, not yet pushed)
- ⏳ Session 7 work NOT YET COMMITTED
