import SwiftUI

/// Dedicated settings page accessible via gear icon from the main screen.
/// Contains Location, Date/Time, Horizon Profile, and Moon Brightness Tiers.
struct SettingsPageView: View {
    @Binding var selectedLocation: Location?
    @Binding var selectedTargets: [Target]
    @Binding var startDate: Date
    @Binding var observationTime: Date
    @Binding var customLat: String
    @Binding var customLon: String
    @Binding var customElevation: String
    @Binding var customTimezone: String
    @Binding var useCustomLocation: Bool
    @Binding var directionalAltitudes: DirectionalAltitudes
    @Binding var duskDawnBuffer: Double
    @Binding var dateRangeDays: Double
    @Binding var moonTierConfig: MoonTierConfig
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var showSavedConfirmation = false

    var body: some View {
        Form {
            SettingsFormContent(
                selectedLocation: $selectedLocation,
                selectedTargets: $selectedTargets,
                startDate: $startDate,
                observationTime: $observationTime,
                customLat: $customLat,
                customLon: $customLon,
                customElevation: $customElevation,
                customTimezone: $customTimezone,
                useCustomLocation: $useCustomLocation,
                directionalAltitudes: $directionalAltitudes,
                duskDawnBuffer: $duskDawnBuffer,
                dateRangeDays: $dateRangeDays,
                moonTierConfig: $moonTierConfig
            )
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onSave()
                    showSavedConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                }
            }
        }
        .overlay {
            if showSavedConfirmation {
                Text("Saved")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSavedConfirmation)
    }
}
