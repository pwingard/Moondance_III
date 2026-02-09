import SwiftUI

struct SearchableTargetPicker: View {
    @Binding var selectedTarget: Target?
    @Binding var isPresented: Bool

    @State private var searchText = ""

    private let dataManager = DataManager.shared

    var body: some View {
        List {
            ForEach(filteredGroups, id: \.0) { group in
                Section(header: Text(group.0)) {
                    ForEach(group.1) { target in
                        Button {
                            selectedTarget = target
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isPresented = false
                            }
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
                                if selectedTarget?.id == target.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Target")
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
