import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - What the Chart Shows

                    sectionHeader("The Benefits of Moon Avoidance")

                    Text("Moondance plots three key values over a 30-day window so you can find the best nights to image your target:")

                    bulletList([
                        ("Moon Altitude (blue line)", "Where the moon sits in the sky. Below 0\u{00B0} means it has set \u{2014} that\u{2019}s ideal."),
                        ("Target Altitude (white line)", "Where your deep-sky target sits. Higher is better \u{2014} above 30\u{00B0} is good, above 50\u{00B0} is excellent."),
                        ("Angular Separation (orange dashed)", "The angle between the moon and your target. This is the most important factor for image quality.")
                    ])

                    // MARK: - Why Separation Matters

                    sectionHeader("Why Angular Separation Matters")

                    Text("Even when the moon is above the horizon, you may still be able to image if your target is far enough away from it. The moon scatters light through the atmosphere, and that scattered light is brightest close to the moon and fades as you move away.")

                    Text("The chart below shows how much moonlight affects sky brightness at different separations, based on the Krisciunas-Schaefer atmospheric scattering model used by professional observatories:")

                    // Embedded graph
                    Image("MoonSeparationGraph")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                        .padding(.vertical, 4)

                    // MARK: - Key Takeaways

                    sectionHeader("Key Takeaways")

                    bulletList([
                        ("90\u{00B0} is optimal", "Minimum scattered moonlight. This is the sweet spot."),
                        ("70\u{00B0}\u{2013}110\u{00B0} is excellent", "All within 15% of optimal. Don\u{2019}t stress about hitting exactly 90\u{00B0}."),
                        ("60\u{00B0} is workable", "About 30% more moonlight than optimal. Narrowband filters help here."),
                        ("Below 45\u{00B0} gets bad fast", "Nearly 50% more moonlight. Expect washed-out backgrounds."),
                        ("Below 30\u{00B0} is rough", "74% more moonlight. Only viable with narrowband on bright targets.")
                    ])

                    // MARK: - Reading the Color Dots

                    sectionHeader("Separation Color Coding")

                    HStack(spacing: 16) {
                        colorDot(.green, ">90\u{00B0} \u{2014} Excellent")
                        colorDot(.yellow, "60\u{00B0}\u{2013}90\u{00B0} \u{2014} Good")
                        colorDot(.red, "<60\u{00B0} \u{2014} Poor")
                    }
                    .padding(.vertical, 4)

                    Text("The colored dots on the chart\u{2019}s separation line use this scale. Green nights are your best imaging opportunities.")

                    // MARK: - Imaging Windows

                    sectionHeader("Imaging Windows")

                    Text("When you toggle \u{201C}Show Imaging Windows,\u{201D} colored bars appear on nights where your target is above 30\u{00B0} and the moon is either below the horizon or the separation is favorable. The bar color follows the same green/yellow/red scale.")

                    // MARK: - Moon Phase Markers

                    sectionHeader("Moon Phase Markers")

                    Text("The blue dots on the moon altitude line change size and color with the moon\u{2019}s phase \u{2014} small and dark for new moon, large and bright for full moon. Vertical dashed lines mark New Moon, First Quarter, Full Moon, and Third Quarter.")

                    Text("The best imaging windows are typically in the days surrounding new moon, when the moon is below the horizon for most of the night.")
                        .foregroundStyle(.secondary)

                    // MARK: - Tips

                    sectionHeader("Planning Tips")

                    bulletList([
                        ("Best case", "Target high in the sky + moon below the horizon = perfect conditions."),
                        ("Good case", "Moon is up but separation is >90\u{00B0} = still great for imaging."),
                        ("Use filters", "Narrowband (Ha, OIII, SII) cuts through moonlight. Useful when separation is 45\u{00B0}\u{2013}70\u{00B0}."),
                        ("Plan ahead", "Look at the 30-day trend to find multi-night stretches of good conditions.")
                    ])

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Understanding the Chart")
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

    private func colorDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
        }
    }
}
