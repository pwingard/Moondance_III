import SwiftUI

struct ContentView: View {
    // MARK: - Settings State

    @AppStorage("selectedLocationId") private var savedLocationId: String = "atlanta"
    @AppStorage("savedLocationJSON") private var savedLocationJSON: String = ""
    @AppStorage("selectedTargetIds") private var savedTargetIds: String = "[\"m42\"]"
    @AppStorage("observationHour") private var savedObservationHour: Int = 22
    @AppStorage("useCustomLocation") private var useCustomLocation: Bool = false
    @AppStorage("customLat") private var customLat: String = ""
    @AppStorage("customLon") private var customLon: String = ""
    @AppStorage("customElevation") private var customElevation: String = "0"
    @AppStorage("customTimezone") private var customTimezone: String = "America/New_York"
    @AppStorage("directionalAltitudes") private var directionalAltitudesJSON: String = "[30,30,30,30,30,30,30,30]"
    @AppStorage("duskDawnBuffer") private var duskDawnBuffer: Double = 1.0
    @AppStorage("dateRangeDays") private var dateRangeDays: Double = 90
    @AppStorage("moonTierConfigJSON") private var moonTierConfigJSON: String = ""

    @State private var directionalAltitudes: DirectionalAltitudes = .defaultValues
    @State private var moonTierConfig: MoonTierConfig = .defaults

    @State private var selectedLocation: Location?
    @State private var selectedTargets: [Target] = []
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
    @State private var showTargetPicker = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    private let targetColors: [Color] = [
        .cyan.opacity(0.8),
        .orange.opacity(0.8),
        .pink.opacity(0.8),
        .purple.opacity(0.8),
        .teal.opacity(0.8),
        .blue.opacity(0.8)
    ]

    private var maxTargets: Int {
        DeviceLimits.maxTargets(forDays: Int(dateRangeDays))
    }

    private var chartTitle: String {
        let targetLabel: String
        switch selectedTargets.count {
        case 0: targetLabel = "Target"
        case 1: targetLabel = selectedTargets[0].name
        case 2: targetLabel = "\(selectedTargets[0].name) & \(selectedTargets[1].name)"
        default:
            let names = selectedTargets.map { $0.name }.joined(separator: ", ")
            if names.count <= 40 {
                targetLabel = names
            } else {
                targetLabel = "\(selectedTargets.count) targets"
            }
        }

        let locationName = selectedLocation?.name ?? "Location"

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "MMM d"
        let startStr = dateFmt.string(from: startDate)
        let endDate = Calendar.current.date(byAdding: .day, value: Int(dateRangeDays) - 1, to: startDate) ?? startDate
        let endStr = dateFmt.string(from: endDate)

        return "\(targetLabel) from \(locationName) (\(startStr) \u{2013} \(endStr))"
    }

    private var isFormValid: Bool {
        guard !selectedTargets.isEmpty else { return false }
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
                landscapeChart(result: result)
                    .preferredColorScheme(.dark)
                    .statusBarHidden()
            } else {
                portraitView
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(
                selectedTarget: selectedTargets.first,
                selectedLocation: selectedLocation,
                startDate: startDate,
                observationTime: observationTime,
                screenshot: feedbackScreenshot,
                targetCount: selectedTargets.count,
                maxTargets: maxTargets,
                dateRangeDays: Int(dateRangeDays),
                calculationDays: calculationResult?.days.count ?? 0
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
            let verticalChrome: CGFloat = 110

            NightBarChartView(
                result: result,
                title: chartTitle,
                chartHeight: geo.size.height - verticalChrome - safeTop - safeBottom,
                moonTierConfig: moonTierConfig
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
                    targetSection

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
                            NightBarChartView(
                                result: result,
                                title: chartTitle,
                                moonTierConfig: moonTierConfig
                            )
                        } header: {
                            Text("Nightly Visibility \u{2014} rotate for fullscreen")
                        }
                        .id("chartSection")

                        Section {
                            SummaryView(
                                result: result,
                                moonTierConfig: moonTierConfig
                            )
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

                    Text("See the Show Astro v0.9")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
                .background(.ultraThinMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsPageView(
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
                            moonTierConfig: $moonTierConfig,
                            onSave: saveSettings
                        )
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
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
            .sheet(isPresented: $showTargetPicker) {
                NavigationStack {
                    SearchableTargetPicker(
                        selectedTargets: $selectedTargets,
                        isPresented: $showTargetPicker,
                        maxTargets: maxTargets
                    )
                }
            }
            .onAppear(perform: restoreSettings)
        }
    }

    // MARK: - Target Section

    private var targetSection: some View {
        Section {
            ForEach(Array(selectedTargets.enumerated()), id: \.element.id) { index, target in
                HStack {
                    Circle()
                        .fill(targetColors[index])
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(target.name)
                        Text("RA: \(target.ra, specifier: "%.2f")\u{00B0}  Dec: \(target.dec, specifier: "%.2f")\u{00B0}")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        selectedTargets.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                showTargetPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(selectedTargets.count >= maxTargets ? .secondary : .accentColor)
                    Text(selectedTargets.isEmpty ? "Select Target" : "Add Target")
                        .foregroundColor(selectedTargets.count >= maxTargets ? .secondary : .primary)
                    Spacer()
                    Text("\(selectedTargets.count)/\(maxTargets)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(selectedTargets.count >= maxTargets)
        } header: {
            Text("Targets")
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

        let targetRAs = selectedTargets.map { $0.ra }
        let targetDecs = selectedTargets.map { $0.dec }
        let targetNames = selectedTargets.map { $0.name }

        let hour = Calendar.current.component(.hour, from: observationTime)
        let calcStartDate = startDate
        let calcEndDate = Calendar.current.date(byAdding: .day, value: Int(dateRangeDays) - 1, to: startDate) ?? startDate

        let calcMinAlts = directionalAltitudes.values
        let calcBuffer = duskDawnBuffer

        Task.detached(priority: .userInitiated) {
            let result = AstronomyEngine.calculate(
                latitude: lat,
                longitude: lon,
                elevation: elevation,
                timezone: timezone,
                targetRAs: targetRAs,
                targetDecs: targetDecs,
                targetNames: targetNames,
                startDate: calcStartDate,
                endDate: calcEndDate,
                observationHour: hour,
                minAltitudes: calcMinAlts,
                duskDawnBufferHours: calcBuffer
            )
            await MainActor.run {
                calculationResult = result
                isCalculating = false
                shouldScrollToChart = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    rotateToLandscape()
                }
            }
        }
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        savedLocationId = selectedLocation?.id ?? ""
        savedObservationHour = Calendar.current.component(.hour, from: observationTime)
        directionalAltitudesJSON = directionalAltitudes.jsonString
        moonTierConfigJSON = moonTierConfig.jsonString

        let targetIds = selectedTargets.map { $0.id }
        if let jsonData = try? JSONEncoder().encode(targetIds),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            savedTargetIds = jsonString
        }

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

        if !savedLocationJSON.isEmpty,
           let jsonData = savedLocationJSON.data(using: .utf8),
           let loc = try? JSONDecoder().decode(Location.self, from: jsonData) {
            selectedLocation = loc
        } else {
            selectedLocation = dm.locations.first { $0.id == savedLocationId }
                ?? dm.locations.first
        }

        if let jsonData = savedTargetIds.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: jsonData) {
            selectedTargets = ids.compactMap { id in
                dm.targets.first { $0.id == id }
            }
        }
        if selectedTargets.isEmpty {
            if let first = dm.targets.first {
                selectedTargets = [first]
            }
        }

        if let hour = Calendar.current.date(from: DateComponents(hour: savedObservationHour)) {
            observationTime = hour
        }

        directionalAltitudes = DirectionalAltitudes.from(jsonString: directionalAltitudesJSON)
        moonTierConfig = moonTierConfigJSON.isEmpty
            ? .defaults
            : MoonTierConfig.from(jsonString: moonTierConfigJSON)
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
        let renderer = ImageRenderer(
            content: NightBarChartView(
                result: result,
                title: chartTitle,
                moonTierConfig: moonTierConfig
            ).frame(width: 800, height: 400)
        )
        renderer.scale = 2.0
        if let image = renderer.uiImage {
            shareItems = [image]
            showShareSheet = true
        }
    }

    // MARK: - Orientation

    private func rotateToLandscape() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in }
    }

    private func rotateToPortrait() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in }
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

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        feedbackScreenshot = renderer.image { context in
            window.layer.render(in: context.cgContext)
        }

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
