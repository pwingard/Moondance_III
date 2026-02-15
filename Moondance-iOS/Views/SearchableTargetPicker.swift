import SwiftUI

struct SearchableTargetPicker: View {
    @Binding var selectedTargets: [Target]
    @Binding var isPresented: Bool
    var maxTargets: Int = 6
    var latitude: Double? = nil
    var directionalAltitudes: DirectionalAltitudes = .defaultValues
    @Binding var favoriteTargetIds: Set<String>

    @State private var searchText = ""
    @State private var wikiTarget: Target?
    @State private var enabledTypes: Set<String> = []
    private let dataManager = DataManager.shared

    private var allTypes: [String] {
        dataManager.targetsByType.keys.sorted()
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
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
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
                }
            } header: {
                Text("Filter by Type")
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
                                    if let mag = target.magnitude {
                                        Text("Mag \(mag, specifier: "%.1f") · \(target.size)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(target.size)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let info = altitudeInfo(for: target), info.maxAlt < info.minAlt {
                                        Text("Max \(info.maxAlt, specifier: "%.0f")° due \(info.direction) · below \(info.minAlt, specifier: "%.0f")° minimum")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
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
        }
        .navigationTitle("Select Targets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if enabledTypes.isEmpty {
                enabledTypes = Set(allTypes)
            }
        }
        .searchable(text: $searchText, prompt: "Search objects...")
        .sheet(item: $wikiTarget) { target in
            WikipediaImageView(target: target)
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

    private var hiddenCount: Int {
        guard latitude != nil else { return 0 }
        return dataManager.targets.filter { neverRises($0) }.count
    }

    private var filteredGroups: [(String, [Target])] {
        let groups = dataManager.targetsByType.sorted { $0.key < $1.key }

        let lowercasedSearch = searchText.lowercased()
        return groups.compactMap { (type, targets) in
            // Apply type filter
            if !enabledTypes.contains(type) { return nil }

            let filtered = targets.filter { target in
                // Hide targets that never rise above the horizon
                if neverRises(target) { return false }
                // Apply search filter
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
