import SwiftUI

struct SearchableTargetPicker: View {
    @Binding var selectedTargets: [Target]
    @Binding var isPresented: Bool
    var maxTargets: Int = 6
    var latitude: Double? = nil
    var directionalAltitudes: DirectionalAltitudes = .defaultValues

    @State private var searchText = ""
    private let dataManager = DataManager.shared

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
                            Text(target.name)
                                .foregroundColor(.primary)
                            Spacer()
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
        .searchable(text: $searchText, prompt: "Search objects...")
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
