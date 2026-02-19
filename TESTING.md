# Moondance Testing Guide

## Automated Tests (run before every release)

Run ⌘U in Xcode. All 58 tests must pass.

| Suite | Count | Covers |
|---|---|---|
| CSVTargetParser | 20 | Parsing, line endings, quoted fields, validation, round-trip export |
| SuggestionEngine | 13 | Gap finding, overlap calculation |
| AstronomyEngine | 12 | Julian date, angular separation, sun/moon positions, sunset/sunrise |
| Moondance-iOSUITests | 3 | App launch (auto-generated) |

---

## Manual Regression Checklist

Run through this before submitting to App Store. Check each box as you go.

### 1. First Launch / Location
- [ ] Fresh install (or delete & reinstall) asks for location permission
- [ ] After granting, the bar chart renders with correct dates and your coordinates
- [ ] Denying location shows a graceful fallback (no crash)

### 2. Bar Chart
- [ ] Tap a target — chart slides up and shows visibility bars
- [ ] Date range scrolls left/right
- [ ] Moon phase and imaging window displayed correctly
- [ ] X button dismisses the chart
- [ ] Switching targets updates the chart

### 3. Target Picker — Search & Filter
- [ ] Search finds targets by name (partial match works)
- [ ] Filter by type (Nebula, Galaxy, etc.) — selecting/deselecting updates list
- [ ] "All Types" resets filters
- [ ] Sort options (Magnitude, Name, Visibility) change order correctly
- [ ] Filter and sort selections persist after closing and reopening the picker

### 4. Moon-Free Filter
- [ ] "Any" / "1h+" / "2h+" / "3h+" segmented control filters the list
- [ ] Date picker changes the reference night — list updates
- [ ] Targets with insufficient moon-free time disappear from list
- [ ] Setting back to "Any" restores all targets

### 5. Visibility Labels
- [ ] During **daytime**: targets show "Up at [time]" (not "Up now")
- [ ] During **nighttime**: targets currently above min altitude show "Up now"
- [ ] Targets not visible tonight show a future date (e.g., "Mar 15")

### 6. Favorites
- [ ] Star a target in the picker — it appears in Favorites section
- [ ] Unstar removes it from Favorites
- [ ] Favorites survive app restart (persisted correctly)

### 7. Custom Targets — Import
- [ ] Tap Import, select a CSV file with 3+ rows
- [ ] Targets appear under Custom section
- [ ] Import result alert shows correct count (e.g., "3 imported")
- [ ] A CSV with a header row (Name, RA, Dec) skips the header correctly
- [ ] A CSV with a bad row shows skip count and reason in the alert
- [ ] CRLF line endings (Excel/Windows CSV) import correctly

### 8. Custom Targets — Export & Delete
- [ ] Tap Export — share sheet appears on first tap (not blank)
- [ ] Exported CSV opens in Numbers/Excel with correct columns
- [ ] Swipe-to-delete removes a custom target
- [ ] Deleted target is gone after app restart

### 9. Suggestion Engine
- [ ] Add 1–2 targets to the chart
- [ ] Open target picker — suggestion section appears with complementary targets
- [ ] Suggestions show time window and moon-free hours
- [ ] Suggestions are different from already-selected targets

### 10. Settings
- [ ] Min altitude slider changes — bar chart updates
- [ ] Dusk/dawn buffer changes — imaging window shrinks/grows
- [ ] Both settings persist after app restart

### 11. Wikipedia Integration
- [ ] Tap the info button on a target — Wikipedia sheet opens
- [ ] Text and image load (requires internet)
- [ ] Works for common targets (M42, M31, etc.)
- [ ] Graceful fallback for targets with no Wikipedia article

### 12. App Store Build
- [ ] Product → Archive succeeds with no errors
- [ ] No signing warnings for either the app or test targets
- [ ] Upload to App Store Connect via Organizer succeeds
- [ ] TestFlight build processes without issues

---

## Known Limitations (not bugs)
- Moon-free filter is slow on first load for large target lists — this is expected (background compute)
- "Up now" label requires device location to be accurate; simulator may show unexpected results
- Sun/moon calculations are accurate to ~1° — sufficient for visual/photographic planning
