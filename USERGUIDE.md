# Moondance Astrophotography Planner — User Guide

---

## What Moondance Does

Moondance plans your deep-sky imaging sessions weeks or months in advance. You pick up to six targets, set your location and horizontal clearances, dial in how much moon you are willing to coexist with, and tap Calculate. The app produces a scrollable night-by-night chart showing exactly when each target is above the trees and how much moon you have to deal with — tonight, next week, next lunar cycle, or even when you're at your dark sky location on vacation nine months from now. In a flash, all at a glance, and without opening a single star chart.

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

When entering a location manually, you can also set **elevation in meters**. The app passes this to the calculation engine — if you're imaging from a high-altitude site, entering it accurately improves precision.

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
- **Filter by type or category** — toggle Galaxies, Nebulae, Dark Nebulae, Planetary Nebulae, Open Clusters, and Globular Clusters on or off

### Sort by Availability

Turn on **Sort by availability** to reorder the list so targets currently in season appear at the top. Targets coming into season soon follow, and targets that won't rise for months are pushed to the bottom. This is purely a list ordering tool — it doesn't hide anything.

### Moon-Free Filter

The Moon-Free Filter is separate from sorting and does something different: it **hides targets** that don't meet a minimum moon-free threshold on a specific night, so you're only choosing from objects that are actually worth imaging that evening.

**How to use it:**

1. Set the **Night** date to the evening you're planning to image.
2. Set **Min moon-free** to the minimum number of uninterrupted moon-free hours you need:
   - **Any** — filter off, all targets shown
   - **1h+** — at least 1 hour of moon-free imaging time
   - **2h+** — at least 2 hours
   - **3h+** — at least 3 hours

With a threshold set, any target that can't deliver that much moon-free time on your chosen night disappears from the list. What remains is a short, focused list of targets that are ready to shoot.

The filter resets to **Any** each time you open the picker — it's a session tool, not a permanent setting.

**Moon-free badge**

When you add a target to your selection while the filter is active, it gets a small badge showing the filter conditions you used — for example, `Feb 21 · 2h+`. The badge appears under the target's name both in the picker and on the main screen, so you always know which targets were selected under a moon filter and which weren't. The badge clears automatically if you remove the target.

### Availability Indicators

In the caption line under the target's name, a colored label indicates when, i.e.:

- **Green** — Visible now (currently rising at night at your location)
- **Yellow** — Rises within 90 days
- **Orange** — Rises in 90+ days
- **Red** — Never rises at your latitude

If a target barely clears your horizon minimum, a second line in orange or red appears below the caption — for example, *"Max 22° due S · barely clears 20° minimum"* — so you know it's marginal before you add it.

### Favorites

Tap the star icon on any target to save it to your Favorites list. Favorites are a quick shortcut for your go-to objects.

### Custom Targets

If your target isn't in the built-in catalog, you can add it manually by entering RA and Dec coordinates directly, or import a CSV file of custom objects (see section 9).

---

## 5. Horizon Profile

Open **Settings → Horizon Profile**.

The horizon profile lets the app know if anything is blocking your sky — trees, rooftops, hills — in each compass direction. There are eight sliders: N, NE, E, SE, S, SW, W, NW. Set each to the minimum altitude a target must reach before you can image it from that direction.

> Example: if a 110-foot tree line blocks your eastern sky up to about 20°, set E and NE to 20°. Targets rising in the east won't appear as "available" until they clear that threshold.

**Set All** applies the same value to every direction at once — useful as a starting point. Then fine-tune individual directions where you have obstructions.

A spider chart then displays your adjustments so you have a quick visual of your settings.

---

## 6. Moon Brightness Tiers

To access this, open **Settings → Moon Brightness Tiers**.

The moon's impact on imaging depends on two things: **how bright the moon is** (its phase) and **how far it is from your target** (angular separation). Moondance lets you set your own tolerance for each phase range.

### The Five Tiers

| Tier | Moon Phase | User Specified Minimum Separation Required |
|------|------------|------------------------------------|
| New | 0–10% | 10° |
| Crescent | 11–25% | 30° |
| Quarter | 26–50% | 60° |
| Gibbous | 51%+ | 90° |
| Cutoff (Adjustable) | 75%+ | No Imaging |

For each tier, you set the **minimum angular separation** (in degrees) you're willing to image under. If the moon is within that angle of your target, the night is rated.

**Cutoff Tier** — Sets a hard limit on moon fullness. Once the moon exceeds this threshold (default 75%), the night is automatically No Imaging regardless of separation or tier settings.

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
The bottom is dusk and the top is dawn. The solid white horizontal line marks 1 AM.

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

As you know, the moon changes from night to night — when it rises, if it rises, and when it sets, if it sets, changes. The percentage of the moon flooding the night sky changes as well — going from no moon to full moon and back to no moon again. Moondance takes the targets you've selected and the settings you've implemented and gives you a rating per target based on how much moon is up, when it's up, and the angular separation — on a per-target basis. These are graded as follows:

**Good (green)** — The moon is below the horizon for your entire imaging window, or the moon phase is ≤10% and separation exceeds your new moon minimum. Best possible conditions.

**Allowable (yellow)** — The moon is up during part or all of your window, but the angular separation, on a per-target basis, surpasses your minimum threshold for the current phase of the moon.

**Mixed (orange)** — Your target has periods within the same imaging session where it beats your minimum threshold requirements, and where it does not.

**No Imaging (red)** — Your target does not meet your minimum requirements — either it isn't up during your imaging window, or the moonlight is too strong based on the thresholds you've set.

> If the target is up but red, it reflects your settings, not an absolute standard. A narrowband imager might rate a night Good that a broadband imager would call No Imaging. Adjust your tiers to match your equipment, taste, and skill.

---

## 9. Smart Suggestions

Moondance can suggest targets based on what's available and what time is still open in your night schedule. Suggestions are similar in nature to what you're already imaging — nebula for nebula, for example. If one of your targets goes down, another may be rising at the same time, and Moondance may suggest it. Tap **Add** to include a suggestion in your current selection.

The button in the app is simply labeled **Suggestions**, but the logic behind it is smart — it scores and ranks candidates based on gap coverage, moon conditions, and type similarity to your existing targets. It's not random picks; it's a scored recommendation engine.

---

## 10. Custom Targets via CSV

If you image targets not in the built-in catalog, you can enter them manually by typing in RA and Dec coordinates directly, or import a list from a CSV file.

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

Your custom target library can also be exported in the same CSV format — useful for backing up or sharing your list. To do this, tap **Export My Custom Targets** inside the target picker.

---

## 11. Exporting Results

Apart from exporting custom targets like above, you can also export your full session results to share with others or keep as a personal reminder. After calculating, tap the **Export** menu in the toolbar on the main screen. You can share your results two ways:

- **Export CSV** — A spreadsheet with one row per target per night, including moon phase, angular separation, visibility hours, moon-free hours, and rating. Open in Excel, Numbers, or any CSV viewer.
- **Share Chart** — Exports the rendered bar chart as a PNG image. Useful for sharing a session plan or saving it for reference.

---

## 12. Planning Tips

**Prioritize moon-free windows.** Even a 2–3 hour moon-free window at the start or end of a night produces cleaner results than a full night under a bright moon.

**Check Mixed nights carefully.** A Mixed rating often means excellent conditions for part of the night. Tap the night for the exact moon-free segment — it may be more useful than it looks.

**Use the horizon profile seriously.** Knowing your tree line is invaluable — and setting it accurately matters just as much. Moondance won't show a target as available until it clears the altitude you've set, so the numbers you enter directly affect your results. There are apps that let you measure the altitude of obstructions around you — use one, plug those numbers in, and let Moondance do the rest.

**Narrowband users: loosen your tiers.**

**Broadband users: tighten your tiers.**

**Use the Moon-Free Filter for spontaneous sessions.** Got an unexpected clear night? Open the target picker, set tonight's date, dial in how many moon-free hours you need, and the list instantly narrows to what's actually worth shooting right now. No star charts, no math — just targets that are ready to go.

**Use Suggestions to fill your nights.** If your primary target sets at 1 AM, the suggestion engine will find you something that rises right as it sets — maximizing your imaging time.

**Plan 90–180 days out.** Some of the best targets spend only a few months in a good position. The longer your planning window, the earlier you can schedule your next great image.

---

*© 2026 Sidestep Studio · Moondance Astrophotography Planner · sidestepstudio.com*
