import SwiftUI

struct ContentView: View {
    // MARK: - Settings State

    @AppStorage("selectedLocationId") private var savedLocationId: String = "atlanta"
    @AppStorage("savedLocationJSON") private var savedLocationJSON: String = ""
    @AppStorage("selectedTargetIds") private var savedTargetIds: String = "[\"m42\"]"
    @AppStorage("targetBadgesJSON") private var targetBadgesJSON: String = "{}"
    // observationHour removed — hardcoded to 22 (10 PM)
    @AppStorage("useCustomLocation") private var useCustomLocation: Bool = false
    @AppStorage("customLat") private var customLat: String = ""
    @AppStorage("customLon") private var customLon: String = ""
    @AppStorage("customElevation") private var customElevation: String = "0"
    @AppStorage("customTimezone") private var customTimezone: String = "America/New_York"
    @AppStorage("directionalAltitudes") private var directionalAltitudesJSON: String = "[30,30,30,30,30,30,30,30]"
    @AppStorage("duskDawnBuffer") private var duskDawnBuffer: Double = 1.0
    @AppStorage("dateRangeDays") private var dateRangeDays: Double = 90
    @AppStorage("moonTierConfigJSON") private var moonTierConfigJSON: String = ""
    @AppStorage("favoriteTargetIds") private var favoriteTargetIdsJSON: String = "[]"

    @State private var directionalAltitudes: DirectionalAltitudes = .defaultValues
    @State private var moonTierConfig: MoonTierConfig = .defaults

    @State private var selectedLocation: Location?
    @State private var selectedTargets: [Target] = []

    @State private var calculationResult: CalculationResult?
    @State private var isCalculating = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shouldScrollToChart = false
    @State private var showFeedback = false
    @State private var feedbackScreenshot: UIImage?
    @State private var showTargetPicker = false
    @State private var showSuggestions = false
    @State private var suggestions: [TargetSuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var showHelp = false
    @State private var showSuggestAlert = false
    @State private var showFavorites = false
    @State private var favoriteTargetIds: Set<String> = []
    @State private var wikiTarget: Target?

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

    private var targetBadgesDict: [String: String] {
        guard let data = targetBadgesJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
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
        let today = Date()
        let startStr = dateFmt.string(from: today)
        let endDate = Calendar.current.date(byAdding: .day, value: Int(dateRangeDays) - 1, to: today) ?? today
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
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(
                selectedTarget: selectedTargets.first,
                selectedLocation: selectedLocation,
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
                moonTierConfig: moonTierConfig,
                targets: selectedTargets
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
                HStack(spacing: 8) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.gray.opacity(0.7))
                            .clipShape(Circle())
                    }
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
                ScrollView {
                    VStack(spacing: 0) {
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
                        }
                        .frame(height: formHeight)

                        if let result = calculationResult {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Nightly Visibility — rotate for fullscreen")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Spacer()
                                    Button {
                                        calculationResult = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.title3)
                                    }
                                }
                                .padding(.horizontal)

                                NightBarChartView(
                                    result: result,
                                    title: chartTitle,
                                    moonTierConfig: moonTierConfig,
                                    targets: selectedTargets
                                )
                                .padding(.horizontal)
                            }
                            .id("chartSection")

                            Form {
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
                            .frame(height: 300)
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

                    HStack(spacing: 8) {
                        Text("Sidestep Studio")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Button {
                            showHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Follow @see_theShow · @SidestepStudio on X")
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
                        Text("Astrophotography Planner and Lunar Sidestepper")
                            .font(.system(size: 9))
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
                        maxTargets: maxTargets,
                        latitude: useCustomLocation ? Double(customLat) : selectedLocation?.lat,
                        longitude: useCustomLocation ? Double(customLon) : selectedLocation?.lon,
                        timezone: useCustomLocation ? customTimezone : (selectedLocation?.timezone ?? "America/New_York"),
                        directionalAltitudes: directionalAltitudes,
                        favoriteTargetIds: $favoriteTargetIds
                    )
                }
            }
            .sheet(isPresented: $showSuggestions) {
                SuggestionView(
                    suggestions: suggestions,
                    selectedCount: selectedTargets.count,
                    maxTargets: maxTargets,
                    onAdd: { target in
                        if selectedTargets.count < maxTargets {
                            selectedTargets.append(target)
                        }
                    },
                    onRemove: { target in
                        selectedTargets.removeAll { $0.id == target.id }
                    }
                )
            }
            .onAppear(perform: restoreSettings)
            .onChange(of: favoriteTargetIds) {
                let favIds = Array(favoriteTargetIds)
                if let jsonData = try? JSONEncoder().encode(favIds),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    favoriteTargetIdsJSON = jsonString
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpView()
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView(
                    favoriteTargetIds: $favoriteTargetIds,
                    selectedTargets: $selectedTargets,
                    maxTargets: maxTargets
                )
            }
            .sheet(item: $wikiTarget) { target in
                WikipediaImageView(target: target)
            }
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
                        Text("\(target.brightnessLabel) · \(target.size)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let badge = targetBadgesDict[target.id] {
                            HStack(spacing: 3) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.caption2)
                                Text(badge)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(4)
                            .foregroundColor(.accentColor)
                        }
                    }
                    Spacer()
                    Button {
                        wikiTarget = target
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    Button {
                        let targetId = selectedTargets[index].id
                        selectedTargets.remove(at: index)
                        var badges = targetBadgesDict
                        badges.removeValue(forKey: targetId)
                        if let data = try? JSONEncoder().encode(badges),
                           let str = String(data: data, encoding: .utf8) {
                            targetBadgesJSON = str
                        }
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

            if !favoriteTargetIds.isEmpty {
                Button {
                    showFavorites = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Favorites")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(favoriteTargetIds.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button {
                if canSuggest {
                    runSuggestions()
                } else {
                    showSuggestAlert = true
                }
            } label: {
                HStack {
                    if isLoadingSuggestions {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(canSuggest ? .yellow : .secondary)
                    }
                    Text("Suggest")
                        .foregroundColor(canSuggest ? .primary : .secondary)
                    Spacer()
                }
            }
            .disabled(isLoadingSuggestions)
            .alert("Pick a Target First", isPresented: $showSuggestAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Suggest finds complementary targets that pair well with your selection — targets with similar visibility windows but spaced far enough from the moon. Add at least one target first, then tap Suggest.")
            }
        } header: {
            Text("Targets")
        }
    }

    /// Height for the target section Form.
    private var formHeight: CGFloat {
        var height: CGFloat = 36       // "Targets" section header
        height += CGFloat(selectedTargets.count) * 56  // 2-line target rows
        height += 44                   // Add Target button
        if !favoriteTargetIds.isEmpty { height += 44 } // Favorites row
        height += 44                   // Suggest button
        if isCalculating { height += 80 }              // spinner section
        height += 48                   // section insets + safety margin
        return height
    }

    private var canSuggest: Bool {
        !selectedTargets.isEmpty && (useCustomLocation ? Double(customLat) != nil : selectedLocation != nil)
    }

    private func runSuggestions() {
        isLoadingSuggestions = true

        let lat: Double
        let lon: Double
        let elev: Double
        let tz: String
        if useCustomLocation {
            lat = Double(customLat) ?? 0
            lon = Double(customLon) ?? 0
            elev = Double(customElevation) ?? 0
            tz = customTimezone
        } else if let loc = selectedLocation {
            lat = loc.lat
            lon = loc.lon
            elev = loc.elevation
            tz = loc.timezone
        } else { return }

        let targets = selectedTargets
        let allTargets = DataManager.shared.targets
        let days = Int(dateRangeDays)
        let alts = directionalAltitudes.values
        let config = moonTierConfig
        let buffer = duskDawnBuffer

        Task {
            let results = SuggestionEngine.suggest(
                selectedTargets: targets,
                allTargets: allTargets,
                latitude: lat,
                longitude: lon,
                elevation: elev,
                timezone: tz,
                dateRangeDays: days,
                minAltitudes: alts,
                moonTierConfig: config,
                duskDawnBufferHours: buffer
            )
            suggestions = results
            isLoadingSuggestions = false
            showSuggestions = true
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

        let hour = 22
        let calcStartDate = Date()
        let calcEndDate = Calendar.current.date(byAdding: .day, value: Int(dateRangeDays) - 1, to: calcStartDate) ?? calcStartDate

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

        let favIds = Array(favoriteTargetIds)
        if let jsonData = try? JSONEncoder().encode(favIds),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            favoriteTargetIdsJSON = jsonString
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
            let cs = CustomTargetStore.shared
            selectedTargets = ids.compactMap { id in
                dm.targets.first { $0.id == id }
                    ?? cs.targets.first { $0.id == id }
            }
        }
        if selectedTargets.isEmpty {
            if let first = dm.targets.first {
                selectedTargets = [first]
            }
        }

        directionalAltitudes = DirectionalAltitudes.from(jsonString: directionalAltitudesJSON)
        moonTierConfig = moonTierConfigJSON.isEmpty
            ? .defaults
            : MoonTierConfig.from(jsonString: moonTierConfigJSON)

        if let jsonData = favoriteTargetIdsJSON.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: jsonData) {
            favoriteTargetIds = Set(ids)
        }
    }

    // MARK: - Export

    private func exportCSV() {
        guard let result = calculationResult else { return }

        var csv = "Date,Target,Moon Phase %,Moon Alt,Target Alt,Angular Separation,Visibility (hrs),Moon-Free (hrs),Moon-Up (hrs),Avg Sep Moon-Up,Rating\n"
        for day in result.days {
            for tr in day.targetResults {
                let rating = moonTierConfig.evaluateMoonAware(
                    moonPhase: day.moonPhase,
                    hoursMoonDown: tr.hoursMoonDown,
                    hoursMoonUp: tr.hoursMoonUp,
                    avgSeparationMoonUp: tr.avgSeparationMoonUp
                )
                let ratingLabel: String
                switch rating {
                case .good: ratingLabel = "Good"
                case .allowable: ratingLabel = "Allowable"
                case .mixed: ratingLabel = "Mixed"
                case .noImaging: ratingLabel = "No Imaging"
                }
                let visHours = tr.visibility?.durationHours ?? 0
                let avgSep = tr.avgSeparationMoonUp.map { String(format: "%.1f", $0) } ?? ""
                csv += "\(day.dateLabel),\(tr.targetName),\(day.moonPhase),\(day.moonAlt),\(tr.targetAlt),\(tr.angularSeparation),\(visHours),\(tr.hoursMoonDown),\(tr.hoursMoonUp),\(avgSep),\(ratingLabel)\n"
            }
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
                moonTierConfig: moonTierConfig,
                targets: selectedTargets
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

#Preview {
    ContentView()
}
