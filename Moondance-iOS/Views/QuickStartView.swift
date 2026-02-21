import SwiftUI

struct QuickStartView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenQuickStart") private var hasSeenQuickStart = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 36)
                Text("Astrophotographers can generally figure out back focus, PixInsight, and polar alignment from instructions written in languages other than English, so you've probably got this. However…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                Text("Quick Start")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 8)
            }
            .padding(.bottom, 32)

            // Steps
            VStack(alignment: .leading, spacing: 20) {
                step(number: "1", text: "Under **Settings**, save your location and timezone")
                step(number: "2", text: "Go to the picker and pick some targets")
                step(number: "3", text: "Tap **Calculate**")
                step(number: "4", text: "Read the chart")
                step(number: "5", text: "Repeat until it looks right")
            }
            .padding(.horizontal, 32)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    hasSeenQuickStart = true
                    dismiss()
                } label: {
                    Text("Got It")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Remind Me Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func step(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.body)
        }
    }
}
