import SwiftUI
import UniformTypeIdentifiers

struct SearchableTargetPicker: View {
    @Binding var selectedTargets: [Target]
    @Binding var isPresented: Bool
    var maxTargets: Int = 6
    var latitude: Double? = nil
    var longitude: Double? = nil
    var timezone: String = "America/New_York"
    var directionalAltitudes: DirectionalAltitudes = .defaultValues
    @Binding var favoriteTargetIds: Set<String>

    @State private var searchText = ""
    @State private var wikiTarget: Target?
    @State private var enabledTypes: Set<String> = []
    @AppStorage("sortByAvailability") private var sortByAvailability = false
    @AppStorage("filterEnabledTypes") private var savedEnabledTypes: String = ""
    @State private var visibilityCache: [String: (label: String, color: Color, daysAway: Int)] = [:]
    @State private var cacheReady = false
    @State private var customRA = ""
    @State private var customDec = ""
    @State private var customName = ""
    @State private var showCoordinateEntry = false
    @State private var showImportPicker = false
    @State private var showExportSheet = false
    @State private var exportItems: [Any] = []
    @State private var importResultMessage: String?
    @State private var showImportResult = false
    private let dataManager = DataManager.shared
    private let customStore = CustomTargetStore.shared

    private var allTypes: [String] {
        var types = dataManager.targetsByType.keys.sorted()
        if !customStore.targets.isEmpty && !types.contains("Custom") {
            types.append("Custom")
        }
        return types
    }

    private var combinedTargets: [Target] {
        dataManager.targets + customStore.targets
    }

    private var combinedTargetsByType: [String: [Target]] {
        var result = dataManager.targetsByType
        if !customStore.targets.isEmpty {
            result["Custom"] = customStore.targets
        }
        return result
    }

    private let targetColors: [Color] = [
        .cyan.opacity(0.8),
        .orange.opacity(0.8),
        .green.opacity(0.8),
        .pink.opacity(0.8),
        .yellow.opacity(0.8),
        .purple.opacity(0.8)
    ]

    var body: some View {
        List {
            if !selectedTargets.isEmpty {
                Section("Selected (\(selectedTargets.count)/\(maxTargets))") {
                    ForEach(Array(selectedTargets.enumerated()), id: \.element.id) { index, target in
                        Button {
                            selectedTargets.removeAll { $0.id == target.id }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(targetColors[index])
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.name)
                                        .foregroundColor(.primary)
                                    HStack(spacing: 4) {
                                        if let mag = target.magnitude {
                                            Text("Mag \(mag, specifier: "%.1f")")
                                        }
                                        Text(target.size)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            if hiddenCount > 0 {
                Section {
                    Text("\(hiddenCount) objects below the horizon at this latitude are hidden")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                FlowLayout(spacing: 8) {
                    ForEach(allTypes, id: \.self) { type in
                        Button {
                            if enabledTypes.contains(type) {
                                enabledTypes.remove(type)
                            } else {
                                enabledTypes.insert(type)
                            }
                        } label: {
                            Text(type)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(enabledTypes.contains(type) ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundColor(enabledTypes.contains(type) ? .white : .primary)
                                .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text("Filter by Type")
            }

            Section {
                if !cacheReady {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading availability...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Toggle("Sort by availability", isOn: $sortByAvailability)
                        .font(.subheadline)
                }
            }

            ForEach(filteredGroups, id: \.0) { group in
                Section(header: Text(group.0)) {
                    ForEach(group.1) { target in
                        Button {
                            toggleTarget(target)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.name)
                                        .foregroundColor(.primary)
                                    HStack(spacing: 4) {
                                        Text("\(target.brightnessLabel) · \(target.size)")
                                        if let vis = visibilityInfo(for: target) {
                                            Text("· \(vis.label)")
                                                .foregroundColor(vis.daysAway == -1 ? .red : vis.color)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    if let info = altitudeInfo(for: target) {
                                        if info.maxAlt < info.minAlt {
                                            Text("Max \(info.maxAlt, specifier: "%.0f")° due \(info.direction) · below \(info.minAlt, specifier: "%.0f")° minimum")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                        } else if info.maxAlt < info.minAlt + 5 {
                                            Text("Max \(info.maxAlt, specifier: "%.0f")° due \(info.direction) · barely clears \(info.minAlt, specifier: "%.0f")° minimum")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                Spacer()

                                Button {
                                    toggleFavorite(target)
                                } label: {
                                    Image(systemName: favoriteTargetIds.contains(target.id) ? "star.fill" : "star")
                                        .foregroundColor(favoriteTargetIds.contains(target.id) ? .yellow : .secondary.opacity(0.4))
                                        .font(.subheadline)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    wikiTarget = target
                                } label: {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                                .buttonStyle(.plain)

                                if let index = selectedTargets.firstIndex(where: { $0.id == target.id }) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(targetColors[index])
                                            .frame(width: 8, height: 8)
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                } else if selectedTargets.count >= maxTargets {
                                    // At capacity — show disabled state
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary.opacity(0.3))
                                }
                            }
                        }
                        .disabled(selectedTargets.count >= maxTargets && !selectedTargets.contains(where: { $0.id == target.id }))
                    }
                }
            }

            Section {
                DisclosureGroup("Enter Coordinates", isExpanded: $showCoordinateEntry) {
                    TextField("Name (optional)", text: $customName)
                        .textInputAutocapitalization(.words)
                    HStack {
                        TextField("RA (degrees)", text: $customRA)
                            .keyboardType(.decimalPad)
                        TextField("Dec (degrees)", text: $customDec)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    Button {
                        addCustomTarget()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Add to Targets")
                        }
                    }
                    .disabled(Double(customRA) == nil || Double(customDec) == nil || selectedTargets.count >= maxTargets)
                }

                Button {
                    showImportPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.accentColor)
                        Text("Import Targets from CSV")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                if !customStore.targets.isEmpty {
                    Button {
                        exportCustomTargets()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                            Text("Export My Custom Targets")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(customStore.targets.count) saved")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Button {
                    requestObject()
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.accentColor)
                        Text("Request an Object")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("Email us")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Can't find what you're looking for?")
            }
        }
        .navigationTitle("Select Targets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if enabledTypes.isEmpty {
                // Restore saved filter selections, or default to all
                if !savedEnabledTypes.isEmpty,
                   let data = savedEnabledTypes.data(using: .utf8),
                   let saved = try? JSONDecoder().decode(Set<String>.self, from: data) {
                    // Keep known types; auto-enable any new types not previously seen
                    let restored = saved.intersection(Set(allTypes))
                    let newTypes = Set(allTypes).subtracting(saved)
                    enabledTypes = restored.union(newTypes)
                    if enabledTypes.isEmpty { enabledTypes = Set(allTypes) }
                } else {
                    enabledTypes = Set(allTypes)
                }
            }
            if !cacheReady {
                buildVisibilityCache()
            }
        }
        .onChange(of: enabledTypes) { _, newTypes in
            // Persist filter selections
            if let data = try? JSONEncoder().encode(newTypes) {
                savedEnabledTypes = String(data: data, encoding: .utf8) ?? ""
            }
        }
        .searchable(text: $searchText, prompt: "Search objects...")
        .sheet(item: $wikiTarget) { target in
            WikipediaImageView(target: target)
        }
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: exportItems)
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importResultMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
            }
        }
    }

    private func toggleTarget(_ target: Target) {
        if let index = selectedTargets.firstIndex(where: { $0.id == target.id }) {
            selectedTargets.remove(at: index)
        } else if selectedTargets.count < maxTargets {
            selectedTargets.append(target)
        }
    }

    private func addCustomTarget() {
        guard let ra = Double(customRA), let dec = Double(customDec),
              selectedTargets.count < maxTargets else { return }
        let name = customName.isEmpty ? "Custom (\(customRA)°, \(customDec)°)" : customName
        let target = Target(
            id: "custom_\(UUID().uuidString.prefix(8))",
            name: name,
            type: "Custom",
            ra: ra,
            dec: dec,
            magnitude: nil,
            surfaceBrightness: nil,
            size: "—"
        )
        customStore.add(target)
        selectedTargets.append(target)
        customRA = ""
        customDec = ""
        customName = ""
        showCoordinateEntry = false
    }

    private func handleImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            importResultMessage = "Could not open file."
            showImportResult = true
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            importResultMessage = "Permission denied for that file."
            showImportResult = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else {
            importResultMessage = "Could not read file."
            showImportResult = true
            return
        }
        let parseResult = CSVTargetParser.parse(data)
        customStore.addAll(parseResult.imported)
        if parseResult.skippedCount == 0 {
            importResultMessage = "Imported \(parseResult.imported.count) targets."
        } else {
            importResultMessage = "Imported \(parseResult.imported.count) targets. \(parseResult.skippedCount) rows skipped (invalid RA/Dec)."
        }
        showImportResult = true
        cacheReady = false
        buildVisibilityCache()
    }

    private func exportCustomTargets() {
        let csv = CSVTargetParser.export(customStore.targets)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("moondance_custom_targets.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        exportItems = [tempURL]
        showExportSheet = true
    }

    private func requestObject() {
        let subject = "Moondance Object Request".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "Hi, I'd like to request the following object be added to Moondance:\n\nObject name: \nCatalog ID (if known): \nNotes: \n".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:seetheshow87@gmail.com?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(url)
        }
    }

    private func toggleFavorite(_ target: Target) {
        if favoriteTargetIds.contains(target.id) {
            favoriteTargetIds.remove(target.id)
        } else {
            favoriteTargetIds.insert(target.id)
        }
    }

    /// Returns true if the target never rises above 0° at the given latitude.
    private func neverRises(_ target: Target) -> Bool {
        guard let lat = latitude else { return false }
        let maxAlt = 90.0 - abs(lat - target.dec)
        return maxAlt < 0
    }

    /// Returns (maxAltitude, transitDirection, minAltInThatDirection) for a target, or nil if no latitude set.
    private func altitudeInfo(for target: Target) -> (maxAlt: Double, direction: String, minAlt: Double)? {
        guard let lat = latitude else { return nil }
        let maxAlt = 90.0 - abs(lat - target.dec)
        let transitsS = target.dec < lat
        let direction = transitsS ? "S" : "N"
        let minAlt = transitsS ? directionalAltitudes.values[4] : directionalAltitudes.values[0]
        return (maxAlt, direction, minAlt)
    }

    /// Returns cached label + color + daysAway for target visibility timing.
    private func visibilityInfo(for target: Target) -> (label: String, color: Color, daysAway: Int)? {
        if let cached = visibilityCache[target.id] {
            return cached
        }
        // Compute on demand if not cached yet
        return computeVisibilityInfo(for: target)
    }

    private func computeVisibilityInfo(for target: Target) -> (label: String, color: Color, daysAway: Int)? {
        guard let lat = latitude, let lon = longitude else { return nil }
        let transitsS = target.dec < lat
        let minAlt = transitsS ? directionalAltitudes.values[4] : directionalAltitudes.values[0]
        let info = AstronomyEngine.firstVisibleInfo(
            targetRA: target.ra, targetDec: target.dec,
            latitude: lat, longitude: lon,
            timezone: timezone,
            minAlt: minAlt
        )
        let color: Color
        switch info.daysAway {
        case 0:
            color = .green
        case -1:
            color = .red
        case 1...90:
            color = .yellow
        default:
            color = .orange
        }
        return (info.label, color, info.daysAway)
    }

    private func buildVisibilityCache() {
        guard let lat = latitude, let lon = longitude else { return }
        let targets = combinedTargets.filter { !neverRises($0) }

        // Pre-compute shared reference values ONCE (Calendar, JD, LST, DateFormatter)
        let ref = AstronomyEngine.VisibilityRef(latitude: lat, longitude: lon, timezone: timezone)

        var cache: [String: (label: String, color: Color, daysAway: Int)] = [:]
        for target in targets {
            let transitsS = target.dec < lat
            let minAlt = transitsS ? directionalAltitudes.values[4] : directionalAltitudes.values[0]
            let info = AstronomyEngine.firstVisibleInfo(
                targetRA: target.ra, targetDec: target.dec,
                ref: ref,
                minAlt: minAlt
            )
            let color: Color
            switch info.daysAway {
            case 0: color = .green
            case -1: color = .red
            case 1...90: color = .yellow
            default: color = .orange
            }
            cache[target.id] = (info.label, color, info.daysAway)
        }
        visibilityCache = cache
        cacheReady = true
    }

    private var hiddenCount: Int {
        guard latitude != nil else { return 0 }
        return dataManager.targets.filter { neverRises($0) }.count
    }

    private var filteredGroups: [(String, [Target])] {
        let groups = combinedTargetsByType.sorted { $0.key < $1.key }

        let lowercasedSearch = searchText.lowercased()

        if sortByAvailability && cacheReady {
            // Flatten all targets, filter, sort by daysAway, return as single group
            let allFiltered = groups.flatMap { (type, targets) -> [Target] in
                if !enabledTypes.contains(type) { return [] }
                return targets.filter { target in
                    if neverRises(target) { return false }
                    if !searchText.isEmpty {
                        return target.name.lowercased().contains(lowercasedSearch) ||
                               target.id.lowercased().contains(lowercasedSearch)
                    }
                    return true
                }
            }
            let sorted = allFiltered.sorted { a, b in
                let aDays = visibilityCache[a.id]?.daysAway ?? 999
                let bDays = visibilityCache[b.id]?.daysAway ?? 999
                let aSortKey = aDays == -1 ? 9999 : aDays
                let bSortKey = bDays == -1 ? 9999 : bDays
                return aSortKey < bSortKey
            }
            return sorted.isEmpty ? [] : [("By Availability", sorted)]
        }

        return groups.compactMap { (type, targets) in
            if !enabledTypes.contains(type) { return nil }

            let filtered = targets.filter { target in
                if neverRises(target) { return false }
                if !searchText.isEmpty {
                    return target.name.lowercased().contains(lowercasedSearch) ||
                           target.id.lowercased().contains(lowercasedSearch)
                }
                return true
            }
            return filtered.isEmpty ? nil : (type, filtered)
        }
    }
}
