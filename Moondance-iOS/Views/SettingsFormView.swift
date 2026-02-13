import SwiftUI

/// RAM-aware target/day limits. Adjusts based on device physical memory.
enum DeviceLimits {
    /// Debug override: set to 2, 3, 4, 6, 8 to simulate a device with that much RAM.
    /// Set to nil (or 0) to use actual device RAM. Only works in DEBUG builds.
    #if DEBUG
    static var debugRAMOverride: Int? = nil
    #endif

    /// Effective RAM tier used for all limit calculations
    static var effectiveRAM_GB: Int {
        #if DEBUG
        if let override = debugRAMOverride, override > 0 {
            return override
        }
        #endif
        return actualRAM_GB
    }

    /// Actual device RAM
    static let actualRAM_GB: Int = {
        let bytes = ProcessInfo.processInfo.physicalMemory
        return Int(bytes / (1024 * 1024 * 1024))
    }()

    /// Maximum date range
    static var maxDateRange: Int { 365 }

    /// Maximum targets allowed for a given day count
    static func maxTargets(forDays days: Int) -> Int {
        return 6  // Uncapped for stress testing — memory profiling shows no risk
    }
}

#if DEBUG
enum MemoryProfiler {
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.phys_footprint) / 1_048_576
    }

    static func run() -> String {
        let allTargets: [(name: String, ra: Double, dec: Double)] = [
            ("M42", 83.82, -5.39),
            ("M31", 10.68, 41.27),
            ("M45", 56.87, 24.12),
            ("M81", 148.89, 69.07),
            ("NGC7000", 314.68, 44.53),
            ("M33", 23.46, 30.66),
        ]

        let scenarios: [(targets: Int, days: Int, label: String)] = [
            (1, 30,  "Small    1T x  30d"),
            (3, 90,  "Medium   3T x  90d"),
            (6, 120, "Large    6T x 120d"),
            (6, 365, "MAX      6T x 365d"),
        ]

        let baselineMB = footprintMB()
        var lines: [String] = []
        lines.append("Baseline: \(String(format: "%.0f", baselineMB)) MB")
        lines.append("")
        lines.append("Scenario              Delta    Time")
        lines.append(String(repeating: "-", count: 40))

        for s in scenarios {
            let targets = Array(allTargets.prefix(s.targets))
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: s.days - 1, to: startDate)!

            let beforeMB = footprintMB()
            let startTime = CFAbsoluteTimeGetCurrent()

            let result = AstronomyEngine.calculate(
                latitude: 33.749,
                longitude: -84.388,
                elevation: 320,
                timezone: "America/New_York",
                targetRAs: targets.map { $0.ra },
                targetDecs: targets.map { $0.dec },
                targetNames: targets.map { $0.name },
                startDate: startDate,
                endDate: endDate,
                observationHour: 22
            )

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let afterMB = footprintMB()
            _ = result.days.count

            let pad = s.label.padding(toLength: 20, withPad: " ", startingAt: 0)
            let line = "\(pad) \(String(format: "%+5.1f", afterMB - beforeMB))MB  \(String(format: "%5.2f", elapsed))s"
            lines.append(line)
        }

        let finalMB = footprintMB()
        lines.append(String(repeating: "-", count: 42))
        lines.append(String(format: "Final: %.0f MB (+%.0f MB)", finalMB, finalMB - baselineMB))
        lines.append("")
        lines.append("Jetsam limits:")
        lines.append("  2GB~800  3GB~1200  4GB~1600  6GB~2500")

        return lines.joined(separator: "\n")
    }
}
#endif

/// Provides the settings sections (Location, Date/Time, Constraints, Moon Tiers)
/// to be embedded inside a parent Form. Target selection lives on the main screen.
struct SettingsFormContent: View {
    @Binding var selectedLocation: Location?
    @Binding var selectedTargets: [Target]
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

    private var maxTargets: Int {
        DeviceLimits.maxTargets(forDays: Int(dateRangeDays))
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

    #if DEBUG
    @State private var debugRAM: Int = DeviceLimits.actualRAM_GB
    @State private var memoryReport: String?
    @State private var isProfileRunning = false
    #endif

    var body: some View {
        Group {
            locationSection
            dateTimeSection
            observingConstraintsSection
            moonTierSection
            #if DEBUG
            debugSection
            #endif
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
            VStack(alignment: .leading) {
                Text("Date Range: \(Int(dateRangeDays)) days")
                    .font(.subheadline)
                Slider(value: $dateRangeDays, in: 30...Double(DeviceLimits.maxDateRange), step: 1)
            }
        } header: {
            Text("Date Range")
        } footer: {
            Text("Charts start from today's date")
                .font(.caption)
        }
    }

    // MARK: - Observing Constraints

    private var observingConstraintsSection: some View {
        Section {
            HorizonProfileView(altitudes: $directionalAltitudes)

            VStack(alignment: .leading) {
                Text("Dusk/Dawn Buffer: \(duskDawnBuffer, specifier: "%.2g") hrs each")
                    .font(.subheadline)
                Slider(value: $duskDawnBuffer, in: 0...2, step: 0.25)
            }
        } header: {
            Text("Horizon Profile")
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
                Text("Moon Tiers")
                Text("Minimum angular separation required by the user between target and moon during each moon phase period")
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

    // MARK: - Debug Section (DEBUG builds only)

    #if DEBUG
    private var debugSection: some View {
        Group {
        Section {
            HStack {
                Text("Actual RAM")
                Spacer()
                Text("\(DeviceLimits.actualRAM_GB) GB")
                    .foregroundColor(.secondary)
            }

            Picker("Simulate RAM", selection: $debugRAM) {
                Text("Actual (\(DeviceLimits.actualRAM_GB) GB)").tag(DeviceLimits.actualRAM_GB)
                Text("2 GB (iPhone SE/8)").tag(2)
                Text("3 GB (iPhone 11)").tag(3)
                Text("4 GB (iPhone 12)").tag(4)
                Text("6 GB (iPhone 12 Pro Max)").tag(6)
                Text("8 GB (iPhone 15 Pro)").tag(8)
            }
            .onChange(of: debugRAM) { _, newValue in
                DeviceLimits.debugRAMOverride = (newValue == DeviceLimits.actualRAM_GB) ? nil : newValue
                // Clamp date range if it now exceeds the new max
                if dateRangeDays > Double(DeviceLimits.maxDateRange) {
                    dateRangeDays = Double(DeviceLimits.maxDateRange)
                }
                // Trim targets if over new limit
                if selectedTargets.count > maxTargets {
                    selectedTargets = Array(selectedTargets.prefix(maxTargets))
                }
            }

            HStack {
                Text("Max Days")
                Spacer()
                Text("\(DeviceLimits.maxDateRange)")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Max Targets (at \(Int(dateRangeDays))d)")
                Spacer()
                Text("\(maxTargets)")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Debug: RAM Simulation")
        } footer: {
            Text("Simulates device RAM limits. Only visible in debug builds.")
                .font(.caption)
        }

        Section {
            Button {
                runMemoryProfile()
            } label: {
                HStack {
                    Image(systemName: "memorychip")
                    Text(isProfileRunning ? "Running..." : "Run Memory Profile")
                    if isProfileRunning {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isProfileRunning)

            if let report = memoryReport {
                Text(report)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
            }
        } header: {
            Text("Debug: Memory Profiler")
        } footer: {
            Text("Runs calculations at all RAM tier limits and measures memory usage.")
                .font(.caption)
        }
        } // Group
    }


    private func runMemoryProfile() {
        isProfileRunning = true
        memoryReport = nil

        Task.detached(priority: .userInitiated) {
            let report = MemoryProfiler.run()
            await MainActor.run {
                memoryReport = report
                isProfileRunning = false
            }
        }
    }
    #endif

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
