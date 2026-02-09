import SwiftUI

/// Provides the settings sections to be embedded inside a parent Form.
struct SettingsFormContent: View {
    @Binding var selectedLocation: Location?
    @Binding var selectedTarget: Target?
    @Binding var startDate: Date
    @Binding var observationTime: Date
    @Binding var customLat: String
    @Binding var customLon: String
    @Binding var customElevation: String
    @Binding var customTimezone: String
    @Binding var useCustomLocation: Bool
    @Binding var useCustomTarget: Bool
    @Binding var customRA: String
    @Binding var customDec: String

    @StateObject private var locationService = LocationService()
    @State private var showTargetPicker = false
    @State private var showLocationSearch = false
    @State private var searchedLocation: Location?

    private let dataManager = DataManager.shared

    /// Binding for Picker that only shows locations from the preset list
    private var pickerLocationBinding: Binding<Location?> {
        Binding(
            get: {
                // Only return if it's a preset location (not GPS or searched)
                if let loc = selectedLocation,
                   dataManager.locations.contains(where: { $0.id == loc.id }) {
                    return loc
                }
                return nil
            },
            set: { newValue in
                selectedLocation = newValue
                // Clear searched location when picking from presets
                searchedLocation = nil
            }
        )
    }

    var body: some View {
        Group {
            locationSection
            targetSection
            dateTimeSection
        }
        .onAppear {
            // Restore searchedLocation if selectedLocation is a searched location
            if let loc = selectedLocation, loc.id.hasPrefix("search-") {
                searchedLocation = loc
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

                // Show searched location
                if let searched = searchedLocation {
                    Button {
                        selectedLocation = searched
                    } label: {
                        HStack {
                            Image(systemName: selectedLocation?.id == searched.id ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundColor(selectedLocation?.id == searched.id ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(searched.name)
                                Text("\(searched.lat, specifier: "%.2f"), \(searched.lon, specifier: "%.2f") • \(searched.timezone.replacingOccurrences(of: "_", with: " "))")
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
                                Text("\(detected.lat, specifier: "%.2f"), \(detected.lon, specifier: "%.2f") • \(detected.timezone.replacingOccurrences(of: "_", with: " "))")
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

    // MARK: - Target Section

    private var targetSection: some View {
        Section {
            if !useCustomTarget {
                Button {
                    showTargetPicker = true
                } label: {
                    HStack {
                        Text("Target")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(selectedTarget?.name ?? "Select...")
                            .foregroundColor(selectedTarget == nil ? .secondary : .primary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .sheet(isPresented: $showTargetPicker) {
                    NavigationStack {
                        SearchableTargetPicker(selectedTarget: $selectedTarget, isPresented: $showTargetPicker)
                    }
                }

                if let target = selectedTarget {
                    HStack {
                        Text("RA: \(target.ra, specifier: "%.4f")°")
                        Spacer()
                        Text("Dec: \(target.dec, specifier: "%.4f")°")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            DisclosureGroup("Custom RA/Dec", isExpanded: $useCustomTarget) {
                TextField("RA (degrees, 0-360)", text: $customRA)
                    .keyboardType(.decimalPad)
                TextField("Dec (degrees, -90 to 90)", text: $customDec)
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Target")
        }
    }

    // MARK: - Date/Time Section

    private var dateTimeSection: some View {
        Section {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("Local Time at Location", selection: $observationTime, displayedComponents: .hourAndMinute)
        } header: {
            Text("Date & Time")
        } footer: {
            Text("Time is interpreted as local time at the observation location")
                .font(.caption)
        }
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
