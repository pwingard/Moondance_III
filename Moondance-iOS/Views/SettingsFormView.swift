import SwiftUI

/// Provides the settings sections (Location, Date/Time, Constraints, Moon Tiers)
/// to be embedded inside a parent Form. Target selection lives on the main screen.
struct SettingsFormContent: View {
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

    @StateObject private var locationService = LocationService()
    @State private var showLocationSearch = false
    @State private var searchedLocation: Location?

    private let dataManager = DataManager.shared

    /// Dynamic target limit based on date range to keep Swift Charts under ~1000 marks
    private var maxTargets: Int {
        let days = Int(dateRangeDays)
        if days <= 120 { return 6 }
        if days <= 180 { return 4 }
        return 2
    }

    /// Binding for Picker that only shows locations from the preset list
    private var pickerLocationBinding: Binding<Location?> {
        Binding(
            get: {
                if let loc = selectedLocation,
                   dataManager.locations.contains(where: { $0.id == loc.id }) {
                    return loc
                }
                return nil
            },
            set: { newValue in
                selectedLocation = newValue
                searchedLocation = nil
            }
        )
    }

    var body: some View {
        Group {
            locationSection
            dateTimeSection
            observingConstraintsSection
            moonTierSection
        }
        .onAppear {
            if let loc = selectedLocation, loc.id.hasPrefix("search-") {
                searchedLocation = loc
            }
        }
        .onChange(of: dateRangeDays) { _, _ in
            if selectedTargets.count > maxTargets {
                selectedTargets = Array(selectedTargets.prefix(maxTargets))
            }
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        Section {
            if !useCustomLocation {
                Picker("Location", selection: pickerLocationBinding) {
                    Text("Select...").tag(nil as Location?)
                    ForEach(dataManager.locations) { loc in
                        Text(loc.name).tag(loc as Location?)
                    }
                }

                HStack {
                    Button {
                        locationService.detectLocation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text(locationService.isDetecting ? "Detecting..." : "Use GPS")
                            if locationService.isDetecting {
                                Spacer()
                                ProgressView()
                            }
                        }
                        .font(.subheadline)
                    }
                    .disabled(locationService.isDetecting)

                    Spacer()

                    Button {
                        showLocationSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .font(.subheadline)
                    }
                }
                .sheet(isPresented: $showLocationSearch) {
                    NavigationStack {
                        LocationSearchView(selectedLocation: $searchedLocation, isPresented: $showLocationSearch)
                    }
                }
                .onChange(of: searchedLocation) { _, newValue in
                    if let loc = newValue {
                        selectedLocation = loc
                    }
                }

                if let searched = searchedLocation {
                    Button {
                        selectedLocation = searched
                    } label: {
                        HStack {
                            Image(systemName: selectedLocation?.id == searched.id ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundColor(selectedLocation?.id == searched.id ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(searched.name)
                                Text("\(searched.lat, specifier: "%.2f"), \(searched.lon, specifier: "%.2f") \u{2022} \(searched.timezone.replacingOccurrences(of: "_", with: " "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .font(.subheadline)
                    }
                }

                if let detected = locationService.detectedLocation {
                    Button {
                        selectedLocation = detected
                        useCustomLocation = false
                    } label: {
                        HStack {
                            Image(systemName: selectedLocation?.id == "gps" ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundColor(selectedLocation?.id == "gps" ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(detected.name)
                                Text("\(detected.lat, specifier: "%.2f"), \(detected.lon, specifier: "%.2f") \u{2022} \(detected.timezone.replacingOccurrences(of: "_", with: " "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .font(.subheadline)
                    }
                }

                if let error = locationService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            DisclosureGroup("Custom Coordinates", isExpanded: $useCustomLocation) {
                TextField("Latitude", text: $customLat)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $customLon)
                    .keyboardType(.decimalPad)
                TextField("Elevation (m)", text: $customElevation)
                    .keyboardType(.decimalPad)
                Picker("Timezone", selection: $customTimezone) {
                    ForEach(commonTimezones, id: \.self) { tz in
                        Text(tz.replacingOccurrences(of: "_", with: " ")).tag(tz)
                    }
                }
            }
        } header: {
            Text("Location")
        }
    }

    // MARK: - Date/Time Section

    private var dateTimeSection: some View {
        Section {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("Local Time at Location", selection: $observationTime, displayedComponents: .hourAndMinute)

            VStack(alignment: .leading) {
                HStack {
                    Text("Date Range: \(Int(dateRangeDays)) days")
                        .font(.subheadline)
                    Spacer()
                    Text("max \(maxTargets) targets")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Slider(value: $dateRangeDays, in: 30...365, step: 1)
            }
        } header: {
            Text("Date & Time")
        } footer: {
            Text("Time is interpreted as local time at the observation location")
                .font(.caption)
        }
    }

    // MARK: - Observing Constraints

    private var observingConstraintsSection: some View {
        Section {
            HorizonProfileView(altitudes: $directionalAltitudes)

            VStack(alignment: .leading) {
                Text("Dusk/Dawn Buffer: \(duskDawnBuffer, specifier: "%.1f") hrs")
                    .font(.subheadline)
                Slider(value: $duskDawnBuffer, in: 0...2, step: 0.25)
            }
        } header: {
            Text("Horizon Profile")
        } footer: {
            Text("Min altitude per compass direction filters low-horizon targets. Buffer excludes time near twilight.")
                .font(.caption)
        }
    }

    // MARK: - Moon Brightness Tiers

    private var moonTierSection: some View {
        Section {
            ForEach(0..<4, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(MoonTierConfig.tierNames[i])
                            .font(.subheadline)
                            .foregroundColor(tierTextColor(i))
                        Text("(\(moonTierConfig.tierRangeLabel(i)))")
                            .font(.caption)
                            .foregroundColor(tierSecondaryColor(i))
                        Spacer()
                        Text("\(Int(moonTierConfig.minSeparations[i]))\u{00B0} sep")
                            .font(.subheadline)
                            .foregroundColor(tierSecondaryColor(i))
                    }
                    Slider(
                        value: $moonTierConfig.minSeparations[i],
                        in: 0...180, step: 5
                    )
                    .tint(tierTextColor(i))
                }
                .listRowBackground(tierRowColor(i))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Full Tier")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("(>\(Int(moonTierConfig.maxMoonPhase))%)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("No imaging")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                HStack {
                    Text("Cutoff")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Slider(value: $moonTierConfig.maxMoonPhase, in: 25...100, step: 5)
                }
            }
            .listRowBackground(Color(white: 0.49))
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Moon Phase (Angular Separation)")
                Text("Minimum angular separation required between target and moon during each moon phase")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.none)
            }
        }
    }

    // MARK: - Moon Tier Colors

    /// Background colors matching the chart bar grayscale (black → subdued gray)
    private func tierRowColor(_ index: Int) -> Color {
        // Midpoints: New ~5%, Crescent ~18%, Quarter ~38%, Gibbous ~63%
        let midpoints: [Double] = [0.05, 0.18, 0.38, 0.63]
        let t = midpoints[index]
        let w = 0.03 + 0.52 * t
        return Color(white: w)
    }

    /// Text color that's readable on each tier background
    private func tierTextColor(_ index: Int) -> Color {
        index <= 2 ? .white : .black
    }

    private func tierSecondaryColor(_ index: Int) -> Color {
        index <= 2 ? .white.opacity(0.6) : .black.opacity(0.6)
    }

    // MARK: - Computed Helpers

    private var commonTimezones: [String] {
        [
            "America/New_York",
            "America/Chicago",
            "America/Denver",
            "America/Phoenix",
            "America/Los_Angeles",
            "America/Anchorage",
            "Pacific/Honolulu",
            "Europe/London",
            "Europe/Paris",
            "Europe/Berlin",
            "Asia/Tokyo",
            "Australia/Sydney"
        ]
    }
}
