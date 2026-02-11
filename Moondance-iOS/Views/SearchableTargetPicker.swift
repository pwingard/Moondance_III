import SwiftUI

struct SearchableTargetPicker: View {
    @Binding var selectedTargets: [Target]
    @Binding var isPresented: Bool
    var maxTargets: Int = 6

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

    private var filteredGroups: [(String, [Target])] {
        let groups = dataManager.targetsByType.sorted { $0.key < $1.key }

        if searchText.isEmpty {
            return groups
        }

        let lowercasedSearch = searchText.lowercased()
        return groups.compactMap { (type, targets) in
            let filtered = targets.filter { target in
                target.name.lowercased().contains(lowercasedSearch) ||
                target.id.lowercased().contains(lowercasedSearch)
            }
            return filtered.isEmpty ? nil : (type, filtered)
        }
    }
}
