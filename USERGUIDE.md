# Moondance Astrophotography Planner — User Guide

---

## What Moondance Does

Moondance plans your deep-sky imaging sessions weeks or months in advance. You pick up to six targets, set your location and horizontal clearances, dial in how much moon you are willing to coexist with, and tap Calculate. The app produces a scrollable night-by-night chart showing exactly when each target is above the tree and how much moon you have to deal with — tonight, next week, next lunar cycle, or even when you are in you're dark spot location nine months from now. In a flash, all at a glance, and without opening a single star chart.

---

## Getting Started

When you first open the app, it defaults to Atlanta, Georgia with M42 (Orion Nebula) selected and a 90-day planning window. Change any of these immediately in **Settings** (gear icon, top left) or by tapping **Add Targets**.

---

## 1. Setting Your Location

Open **Settings → Location**

- **Preset cities** — choose from the dropdown for a quick start
- **Use GPS** — detects your current location automatically
- **Search** — find any city or address worldwide
- **Manual entry** — enter latitude, longitude, and elevation directly

Set your **timezone** so rise/set times display correctly in local time.

What is this? -> Elevation affects atmospheric refraction calculations. If you're at significant altitude, entering it accurately improves precision.

---

## 2. Date Range

In **Settings**, set how many nights to plan across — from 30 to 365 days. The chart always starts from today. A 90-day window is a good default for seasonal planning; extend to 180–365 days when you want to see what's coming later in the year.

---

## 3. Dusk / Dawn Buffer

This controls when "darkness" begins and ends each night. The default is 1 hour after sunset and 1 hour before sunrise, which approximates astronomical twilight at most latitudes. Increase it if your skies stay bright longer; decrease it if you want to squeeze every minute of dark sky.

---

## 4. Selecting Targets

Tap **Add Targets** to open the target picker. You can select up to six objects simultaneously.

### Searching and Filtering

- **Search** by name or catalog ID (M42, NGC 7000, Horsehead, etc.)
- **Filter by type or category** — toggle Galaxies, Nebulae, Open Clusters, Globular Clusters, Supernova Remnants, and more on or off
- **Sort by availability** — reorders the list so targets coming into season appear first
- **Moon-free filter** — shows only targets with a minimum number of moon-free hours on a chosen night

### Availability Indicators

Each target shows a color indicator:

| Color | Meaning |
|-------|---------|
| Green | Visible now |
| Yellow | Rises within 90 days |
| Orange | Rises in 90+ days |
| Red | Never rises at your latitude |

Targets also show a warning if they barely clear your horizon minimum — useful for knowing which targets need a clear southern horizon.

### Favorites

Tap the star icon on any target to save it to your Favorites list. Favorites are a quick shortcut for your go-to objects.

### Custom Targets

If your target isn't in the built-in catalog, you can add it manually by entering RA and Dec coordinates directly, or import a CSV file of custom objects (see section 9).

---

## 5. Horizon Profile

Open **Settings → Horizon Profile**.

The horizon profile tells the app what's actually blocking your sky — trees, rooftops, hills — in each compass direction. There are eight sliders: N, NE, E, SE, S, SW, W, NW. Set each to the minimum altitude a target must reach before you can image it from that direction.

**Set All** applies the same value to every direction at once — useful as a starting point. Then fine-tune individual directions where you have obstructions.

A radar diagram updates in real time as you adjust, giving you a visual of your horizon shape.

> Example: if a 30-foot tree line blocks your eastern sky up to about 20°, set E and NE to 20°. Targets rising in the east won't appear as "available" until they clear that threshold.

---

## 6. Moon Brightness Tiers

This is the most powerful and most personal setting in the app. Open **Settings → Moon Brightness Tiers**.

The moon's impact on imaging depends on two things: **how bright the moon is** (its phase) and **how far it is from your target** (angular separation). Moondance lets you set your own tolerance for each phase range.

### The Four Tiers

| Tier | Moon Phase | Default Min Separation |
|------|------------|----------------------|
| New | 0–10% | 10° |
| Crescent | 11–25% | 30° |
| Quarter | 26–50% | 60° |
| Gibbous | 51%+ | 90° |

For each tier, you set the **minimum angular separation** (in degrees) you're willing to image under. If the moon is within that angle of your target, the night is rated No Imaging for that tier. If it's farther away, it's Allowable.

### Moon Phase Cutoff

The **Gibbous cutoff** setting (default 75%) defines the maximum moon phase you'll ever image under, regardless of separation. Any night above this threshold is automatically No Imaging.

### Why Separation Matters

Angular separation is the distance in the sky between the moon and your target. Even when the moon is below full, scattered moonlight reduces contrast significantly at close angles:

- **90°+** — Optimal, least interference
- **70–90°** — Very close to optimal
- **60°** — Workable, ~30% more moonlight than ideal
- **< 45°** — Significant interference
- **< 30°** — Major interference, most broadband targets will suffer

Narrowband imagers (Ha, OIII, SII filters) can tolerate much tighter separations and brighter phases than broadband (LRGB) imagers. Set your tiers to match your filter kit.

---

## 7. Reading the Chart

After tapping **Calculate**, the app produces a night-by-night bar chart. Rotate to landscape for the full-screen view.

### Chart Elements

**X-axis — Dates**
Each column is one night. Scroll left and right to move through your date range.

**Y-axis — Clock Time**
Time runs from roughly 8 PM at the top to 5 AM at the bottom, centered around 1 AM. The solid white horizontal line marks 1 AM.

**Dark gray background bar**
The height of the dark background shows how long astronomical darkness lasts that night. Taller = more dark hours.

**White glow**
The white wash inside the column represents moonlight. Brighter and taller = more moon, higher in the sky. A column with no white glow is a moon-free night.

**Colored bars**
Each target gets its own color (shown in the legend above the chart). The bar shows exactly when that target is above your minimum altitude. A taller bar means the target is up longer.

**Rating strip**
A thin colored band at the base of each target bar summarizes the night's imaging quality for that target:

| Color | Rating | Meaning |
|-------|--------|---------|
| Green | Good | Moon-free window, or new moon with separation met |
| Yellow | Allowable | Moon is up but separation meets your tier settings |
| Orange | Mixed | Part moon-free, part doesn't meet your settings |
| Red | No Imaging | Separation doesn't meet your settings, or moon exceeds your cutoff |

**Moon rise/set tick marks**
A small white mark on the left edge of a column indicates where the moon rises or sets — but only when that event falls during one of your target's visibility windows. This lets you see at a glance when the moon enters or exits the scene mid-session.

### Tapping a Night

Tap any column to open a summary tooltip showing:
- Darkness window and total dark hours
- Moon phase and whether it's visible
- Each target's rating for that night

Tap any target in the tooltip for a play-by-play breakdown: when it rises, how long it's moon-free, when the moon comes up, and exactly when to image.

Tap the moon in the tooltip for moon rise, set, and duration details.

---

## 8. Understanding the Ratings

Moondance evaluates each target each night by comparing your moon tier settings against actual conditions.

**Good (green)** — The moon is below the horizon for your entire imaging window, or the moon phase is ≤10% and separation exceeds your new moon minimum. Best possible conditions.

**Allowable (yellow)** — The moon is up during part or all of your window, but angular separation exceeds your threshold for the current phase tier. You've told the app this is acceptable, and the app agrees.

**Mixed (orange)** — Your target's visibility spans both a moon-free period and a moon-up period where separation doesn't meet your settings. You have some good time and some marginal time.

**No Imaging (red)** — The moon's phase and separation combination doesn't meet any of your tier thresholds, or the moon phase exceeds your cutoff entirely. Per your settings, this night isn't worth shooting.

> These ratings reflect **your** settings, not an absolute standard. A narrowband imager might rate a night Good that a broadband imager would call No Imaging. Adjust your tiers to match your workflow.

---

## 9. Smart Suggestions

After calculating, Moondance analyzes your selected targets' combined visibility and finds targets that fill the gaps — times when none of your selected targets are up.

Open **Suggestions** to see ranked recommendations. Each suggestion shows:
- What gap it fills and for how long
- Imaging conditions during that window
- Whether it's in season now, or when it comes into season

Tap **Add** to include a suggestion in your current selection.

The engine samples three representative nights across your date range, scores candidates on gap coverage, moon conditions, and type similarity to your existing selections, and returns the top 12.

---

## 10. Custom Targets via CSV

If you image targets not in the built-in catalog, you can import them from a CSV file.

### File Format

```
Name,RA,Dec,Magnitude,Size
My Nebula,83.82,-5.39,4.0,30'×20'
Custom Galaxy,150.5,20.2,,
```

- **RA**: Right ascension in decimal degrees (0–360) — required
- **Dec**: Declination in decimal degrees (-90 to +90) — required
- **Name**: Optional (auto-generated if omitted)
- **Magnitude** and **Size**: Optional, for display only

The parser accepts standard line endings and quoted fields containing commas. A header row is detected and skipped automatically. Any rows with invalid coordinates are reported individually so you can fix them.

### Exporting Your Custom Targets

Your custom target library can be exported in the same CSV format — useful for backing up or sharing your list.

---

## 11. Exporting Results

Once you've calculated, you can share your results two ways:

- **Export CSV** — A spreadsheet with one row per target per night, including moon phase, angular separation, visibility hours, moon-free hours, and rating. Open in Excel, Numbers, or any CSV viewer.
- **Share Chart** — Exports the rendered bar chart as a PNG image. Useful for sharing a session plan or saving it for reference.

---

## 12. Planning Tips

**Prioritize moon-free windows.** Even a 2–3 hour moon-free window at the start or end of a night produces cleaner results than a full night under a bright moon.

**Check Mixed nights carefully.** A Mixed rating often means excellent conditions for part of the night. Tap the night for the exact moon-free segment — it may be more useful than it looks.

**Use the horizon profile seriously.** Targets that barely clear your horizon spend most of their time in poor seeing and high extinction. If max altitude is under 30°, consider saving them for a dark-sky trip.

**Narrowband users: loosen your tiers.** Ha, OIII, and SII filters block most moonlight. Many narrowband imagers set their Crescent and Quarter thresholds to 30° or less. Experiment to find your own limits.

**Broadband users: tighten your tiers.** LRGB is far more sensitive to moonlight. Quarter and Gibbous thresholds of 90° or more, with a low moon phase cutoff, will save you frustration.

**Use Suggestions to fill your nights.** If your primary target sets at 1 AM, the suggestion engine will find you something that rises right as it sets — maximizing your imaging time.

**Plan 90–180 days out.** Some of the best targets spend only a few months in a good position. The longer your planning window, the earlier you can schedule your next great image.

---

*Moondance Astrophotography Planner · Sidestep Studio · sidestepstudio.com*
