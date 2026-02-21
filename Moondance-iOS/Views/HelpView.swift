import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - User Guide Link

                    Link(destination: URL(string: "https://sidestepstudio.com/moondance-user-guide.pdf")!) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Download the Full User Guide (PDF)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // MARK: - Overview

                    sectionHeader("Understanding the Chart")

                    Text("Moondance plots nightly visibility for up to 6 deep-sky targets across your date range. Each night is a column. Rotate to landscape for the full-screen view.")

                    // MARK: - Bar Columns

                    sectionHeader("Target Bars")

                    Text("Each column spans from dusk to dawn. Colored bars show when each target is above your minimum altitude (set per compass direction in Settings).")

                    bulletList([
                        ("Multiple targets", "Each target gets its own colored sub-bar within the column. Colors are assigned in order: purple, brown, blue, teal, navy, pink."),
                        ("Bar height", "Taller bars mean more hours of visibility that night."),
                        ("Tap a column", "Opens a detail sheet with a play-by-play narrative of imaging conditions throughout the night.")
                    ])

                    // MARK: - Rating Strips

                    sectionHeader("Rating Color Strips")

                    Text("A thin colored strip at the base of each target bar shows the imaging rating for that target on that night:")

                    HStack(spacing: 12) {
                        ratingChip(.green, "Good")
                        ratingChip(.yellow, "Allowable")
                        ratingChip(.orange, "Mixed")
                        ratingChip(.red, "No Imaging")
                    }
                    .padding(.vertical, 4)

                    bulletList([
                        ("Green \u{2014} Good", "Moon is below the horizon or in its new phase during the target\u{2019}s visibility. Best conditions."),
                        ("Yellow \u{2014} Allowable", "Moon is up but your angular separation settings are met. Imaging is viable per your configured thresholds."),
                        ("Orange \u{2014} Mixed", "Part of the night is moon-free and part doesn\u{2019}t meet your settings. Some usable time."),
                        ("Red \u{2014} No Imaging", "Angular separation doesn\u{2019}t meet your settings. The label \u{201C}per settings\u{201D} reminds you this is based on your configured thresholds, not physics.")
                    ])

                    // MARK: - Moon Glow

                    sectionHeader("Moon Glow Background")

                    Text("The white background glow behind the bars represents moon brightness throughout the night. Brighter glow = higher moon altitude \u{00D7} moon phase. A sharp edge shows moonrise or moonset. Dark background means no moon \u{2014} ideal conditions.")

                    // MARK: - Detail Sheet

                    sectionHeader("Tapping a Night")

                    Text("Tap any column to see a detailed breakdown:")

                    bulletList([
                        ("Play-by-play", "A flowing narrative describes each segment of the night: \u{201C}Good imaging for 3.2 hrs moon-free until 1:30 AM\u{201D} followed by \u{201C}No imaging for 2.1 hrs with 65% moon (per settings) until predawn.\u{201D}"),
                        ("Target details", "Shows rise/set azimuths with 16-point compass directions, directional minimum altitudes, and whether the target was already up at dusk or still up at dawn."),
                        ("Moon details", "Tap the moon line to see phase, rise/set times, and duration above the horizon.")
                    ])

                    // MARK: - Moon Tiers

                    sectionHeader("Moon Tier Settings")

                    Text("In Settings, you configure the minimum angular separation required between the moon and your target for each moon phase tier:")

                    bulletList([
                        ("New (0\u{2013}10%)", "Moon barely visible. Default: 10\u{00B0} separation required."),
                        ("Crescent (11\u{2013}25%)", "Slim crescent. Default: 30\u{00B0} required."),
                        ("Quarter (26\u{2013}50%)", "Half moon. Default: 60\u{00B0} required."),
                        ("Gibbous (51%+)", "Bright moon. Default: 90\u{00B0} required.")
                    ])

                    Text("When the actual separation meets your tier threshold, the rating is \u{201C}Allowable.\u{201D} When the moon is below the horizon, separation doesn\u{2019}t matter \u{2014} it\u{2019}s always \u{201C}Good.\u{201D}")
                        .foregroundStyle(.secondary)

                    // MARK: - Horizon Profile

                    sectionHeader("Directional Horizon Profile")

                    Text("Set a minimum altitude for each of 8 compass directions (N, NE, E, SE, S, SW, W, NW). Targets are only considered \u{201C}visible\u{201D} when they\u{2019}re above the threshold for their current azimuth. Use this to model treelines, buildings, or mountains on your horizon.")

                    // MARK: - Suggestions

                    sectionHeader("Smart Suggestions")

                    Text("The Suggest button in the Targets section analyzes gaps in your selected targets\u{2019} visibility and recommends objects that fill unused night time. Suggestions are ranked by gap coverage and moon conditions. Targets not yet in season are flagged with their availability date.")

                    // MARK: - Tips

                    sectionHeader("Planning Tips")

                    bulletList([
                        ("Best case", "Target high in the sky + moon below the horizon = perfect conditions."),
                        ("Use the gap", "If your target sets at midnight, use Suggest to find targets for the second half of the night."),
                        ("Narrowband helps", "Ha, OIII, SII filters cut through moonlight. Consider relaxing your tier thresholds when using narrowband."),
                        ("Plan ahead", "Use a 90+ day range to find multi-night stretches and spot seasonal targets coming into view.")
                    ])

                    // MARK: - Why Separation Matters

                    sectionHeader("Why Angular Separation Matters")

                    Text("Even when the moon is above the horizon, you can image if your target is far enough away. The moon scatters light through the atmosphere \u{2014} brightest near the moon, fading with distance.")

                    Image("MoonSeparationGraph")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                        .padding(.vertical, 4)

                    bulletList([
                        ("90\u{00B0} is optimal", "If you\u{2019}re going to image during the moon, 90\u{00B0} angular separation offers the least moonlight interference."),
                        ("70\u{00B0}\u{2013}110\u{00B0} is a close second", "All within 15% of optimal."),
                        ("60\u{00B0} is workable", "About 30% more moonlight. Narrowband helps."),
                        ("Below 45\u{00B0}", "Nearly 50% more moonlight."),
                        ("Below 30\u{00B0}", "74% more moonlight. Narrowband on bright targets only, if then.")
                    ])

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Understanding the Charts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .fontWeight(.bold)
            .padding(.top, 4)
    }

    private func bulletList(_ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.0) { title, detail in
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{2022}")
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .fontWeight(.semibold)
                        Text(detail)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(.subheadline)
    }

    private func ratingChip(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 8)
            Text(label)
                .font(.caption2)
        }
    }
}
