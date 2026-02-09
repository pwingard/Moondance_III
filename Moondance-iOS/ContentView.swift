import SwiftUI

struct ContentView: View {
    // MARK: - Settings State

    @AppStorage("selectedLocationId") private var savedLocationId: String = "atlanta"
    @AppStorage("savedLocationJSON") private var savedLocationJSON: String = ""
    @AppStorage("selectedTargetId") private var savedTargetId: String = "m42"
    @AppStorage("observationHour") private var savedObservationHour: Int = 22
    @AppStorage("useCustomLocation") private var useCustomLocation: Bool = false
    @AppStorage("useCustomTarget") private var useCustomTarget: Bool = false
    @AppStorage("customLat") private var customLat: String = ""
    @AppStorage("customLon") private var customLon: String = ""
    @AppStorage("customElevation") private var customElevation: String = "0"
    @AppStorage("customTimezone") private var customTimezone: String = "America/New_York"
    @AppStorage("customRA") private var customRA: String = ""
    @AppStorage("customDec") private var customDec: String = ""

    @State private var selectedLocation: Location?
    @State private var selectedTarget: Target?
    @State private var startDate = Date()
    @State private var observationTime = Calendar.current.date(
        from: DateComponents(hour: 22, minute: 0)
    ) ?? Date()

    @State private var calculationResult: CalculationResult?
    @State private var isCalculating = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shouldScrollToChart = false
    @State private var showFeedback = false
    @State private var feedbackScreenshot: UIImage?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    private var chartTitle: String {
        let targetName = selectedTarget?.name ?? "Target"
        let locationName = selectedLocation?.name ?? "Location"

        // Get the location's timezone
        let tzIdentifier = selectedLocation?.timezone ?? customTimezone
        let tz = TimeZone(identifier: tzIdentifier) ?? .current
        let tzAbbrev = tz.abbreviation() ?? tzIdentifier

        // Show the observation hour - the picker hour is used directly as local time at the location
        let hour = Calendar.current.component(.hour, from: observationTime)
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm = hour < 12 ? "AM" : "PM"
        let timeStr = "\(hour12):00 \(ampm) local"

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "MMM d"
        let startStr = dateFmt.string(from: startDate)
        let endDate = Calendar.current.date(byAdding: .day, value: 29, to: startDate) ?? startDate
        let endStr = dateFmt.string(from: endDate)

        return "\(targetName) from \(locationName) at \(timeStr) \(tzAbbrev) (\(startStr) – \(endStr))"
    }

    private var isFormValid: Bool {
        if useCustomTarget {
            guard Double(customRA) != nil, Double(customDec) != nil else { return false }
        } else {
            guard selectedTarget != nil else { return false }
        }
        if useCustomLocation {
            guard Double(customLat) != nil, Double(customLon) != nil else { return false }
            guard !customTimezone.isEmpty else { return false }
        } else {
            guard selectedLocation != nil else { return false }
        }
        return true
    }

    var body: some View {
        Group {
            if isLandscape, let result = calculationResult {
                // Landscape: full-screen chart
                landscapeChart(result: result)
                    .preferredColorScheme(.dark)
                    .statusBarHidden()
            } else {
                // Portrait: normal form layout
                portraitView
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(
                selectedTarget: selectedTarget,
                selectedLocation: selectedLocation,
                startDate: startDate,
                observationTime: observationTime,
                screenshot: feedbackScreenshot
            )
        }
    }

    // MARK: - Landscape Chart

    private func landscapeChart(result: CalculationResult) -> some View {
        GeometryReader { geo in
            let safeLeft = geo.safeAreaInsets.leading
            let safeRight = geo.safeAreaInsets.trailing
            let safeBottom = geo.safeAreaInsets.bottom
            let safeTop = geo.safeAreaInsets.top
            let verticalChrome: CGFloat = 110 // title + toggle + legend + x-axis labels + spacing

            ChartView(
                result: result,
                title: chartTitle,
                chartHeight: geo.size.height - verticalChrome - safeTop - safeBottom
            )
            .padding(.leading, safeLeft + 40)
            .padding(.trailing, max(safeRight, 16))
            .padding(.top, max(safeTop, 8))
            .padding(.bottom, max(safeBottom, 36))
            .overlay(alignment: .topLeading) {
                Button {
                    rotateToPortrait()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.gray.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(.top, 8)
                .padding(.leading, 8)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    captureScreenshotAndShowFeedbackFromLandscape()
                } label: {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.gray.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
            .background(Color.black)
        }
        .ignoresSafeArea()
    }

    // MARK: - Portrait View

    private var portraitView: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                Form {
                    SettingsFormContent(
                        selectedLocation: $selectedLocation,
                        selectedTarget: $selectedTarget,
                        startDate: $startDate,
                        observationTime: $observationTime,
                        customLat: $customLat,
                        customLon: $customLon,
                        customElevation: $customElevation,
                        customTimezone: $customTimezone,
                        useCustomLocation: $useCustomLocation,
                        useCustomTarget: $useCustomTarget,
                        customRA: $customRA,
                        customDec: $customDec
                    )

                    if isCalculating {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView("Calculating...")
                                Spacer()
                            }
                        }
                    }

                    if let result = calculationResult {
                        Section {
                            ChartView(result: result, title: chartTitle)
                        } header: {
                            Text("Chart — rotate for fullscreen")
                        }
                        .id("chartSection")

                        Section {
                            SummaryView(result: result)
                        } header: {
                            Text("Recommendations")
                        }

                        Section {
                            Button {
                                exportCSV()
                            } label: {
                                Label("Export CSV", systemImage: "tablecells")
                            }

                            Button {
                                exportChart()
                            } label: {
                                Label("Share Chart", systemImage: "square.and.arrow.up")
                            }
                        } header: {
                            Text("Export")
                        }
                    }
                }
                .onChange(of: shouldScrollToChart) { _, shouldScroll in
                    if shouldScroll {
                        withAnimation {
                            scrollProxy.scrollTo("chartSection", anchor: .top)
                        }
                        shouldScrollToChart = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button {
                        runCalculation()
                    } label: {
                        HStack {
                            if isCalculating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text("Calculate")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid || isCalculating)
                    .padding(.horizontal)

                    Text("See the Show Astro v0.8")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
                .background(.ultraThinMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Moondance")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Lunar Sidestep Planner")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        captureScreenshotAndShowFeedback()
                    } label: {
                        Image(systemName: "exclamationmark.bubble")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            .onAppear(perform: restoreSettings)
        }
    }

    // MARK: - Calculation

    private func runCalculation() {
        saveSettings()
        isCalculating = true

        let lat: Double
        let lon: Double
        let elevation: Double
        let timezone: String

        if useCustomLocation {
            lat = Double(customLat) ?? 0
            lon = Double(customLon) ?? 0
            elevation = Double(customElevation) ?? 0
            timezone = customTimezone
        } else if let loc = selectedLocation {
            lat = loc.lat
            lon = loc.lon
            elevation = loc.elevation
            timezone = loc.timezone
        } else { return }

        let ra: Double
        let dec: Double

        if useCustomTarget {
            ra = Double(customRA) ?? 0
            dec = Double(customDec) ?? 0
        } else if let target = selectedTarget {
            ra = target.ra
            dec = target.dec
        } else { return }

        // Extract hour - this is the hour the user selected in their local timezone
        // We want to use this same hour in the observation location's timezone
        let hour = Calendar.current.component(.hour, from: observationTime)
        let calcStartDate = startDate

        // DEBUG: Print calculation parameters
        print("=== CALCULATION DEBUG ===")
        print("Location: \(selectedLocation?.name ?? "custom") at lat=\(lat), lon=\(lon)")
        print("Timezone: \(timezone)")
        print("Observation hour: \(hour)")
        print("Target: RA=\(ra), Dec=\(dec)")
        print("Start date: \(calcStartDate)")
        print("=========================")
        let calcEndDate = Calendar.current.date(byAdding: .day, value: 29, to: startDate) ?? startDate

        Task.detached(priority: .userInitiated) {
            let result = AstronomyEngine.calculate(
                latitude: lat,
                longitude: lon,
                elevation: elevation,
                timezone: timezone,
                targetRA: ra,
                targetDec: dec,
                startDate: calcStartDate,
                endDate: calcEndDate,
                observationHour: hour
            )
            await MainActor.run {
                calculationResult = result
                isCalculating = false
                shouldScrollToChart = true
                // Rotate to landscape after a brief delay for scroll to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    rotateToLandscape()
                }
            }
        }
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        savedLocationId = selectedLocation?.id ?? ""
        savedTargetId = selectedTarget?.id ?? ""
        savedObservationHour = Calendar.current.component(.hour, from: observationTime)

        // Save full location data for GPS/searched locations
        if let loc = selectedLocation,
           loc.id.hasPrefix("gps") || loc.id.hasPrefix("search-") {
            if let jsonData = try? JSONEncoder().encode(loc),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                savedLocationJSON = jsonString
            }
        } else {
            savedLocationJSON = ""
        }
    }

    private func restoreSettings() {
        let dm = DataManager.shared

        // Try to restore GPS/searched location from JSON first
        if !savedLocationJSON.isEmpty,
           let jsonData = savedLocationJSON.data(using: .utf8),
           let loc = try? JSONDecoder().decode(Location.self, from: jsonData) {
            selectedLocation = loc
        } else {
            selectedLocation = dm.locations.first { $0.id == savedLocationId }
                ?? dm.locations.first
        }

        selectedTarget = dm.targets.first { $0.id == savedTargetId }
            ?? dm.targets.first

        if let hour = Calendar.current.date(from: DateComponents(hour: savedObservationHour)) {
            observationTime = hour
        }
    }

    // MARK: - Export

    private func exportCSV() {
        guard let result = calculationResult else { return }

        var csv = "Date,Moon Alt,Moon Phase %,Target Alt,Angular Separation,Imaging Window (hrs)\n"
        for day in result.days {
            csv += "\(day.dateLabel),\(day.moonAlt),\(day.moonPhase),\(day.targetAlt),\(day.angularSeparation),\(day.imagingWindow.durationHours)\n"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("moondance_results.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        shareItems = [tempURL]
        showShareSheet = true
    }

    @MainActor
    private func exportChart() {
        guard let result = calculationResult else { return }
        let renderer = ImageRenderer(content: ChartView(result: result, title: chartTitle).frame(width: 800, height: 400))
        renderer.scale = 2.0
        if let image = renderer.uiImage {
            shareItems = [image]
            showShareSheet = true
        }
    }

    // MARK: - Orientation

    private func rotateToLandscape() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
            // Silently ignore errors - user can manually rotate if needed
        }
    }

    private func rotateToPortrait() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
            // Silently ignore errors - user can manually rotate if needed
        }
    }

    // MARK: - Feedback

    private func captureScreenshotAndShowFeedback() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            showFeedback = true
            return
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        feedbackScreenshot = renderer.image { context in
            window.layer.render(in: context.cgContext)
        }
        showFeedback = true
    }

    private func captureScreenshotAndShowFeedbackFromLandscape() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            showFeedback = true
            return
        }

        // Capture the landscape screenshot first
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        feedbackScreenshot = renderer.image { context in
            window.layer.render(in: context.cgContext)
        }

        // Rotate to portrait, then show feedback after rotation completes
        rotateToPortrait()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showFeedback = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
