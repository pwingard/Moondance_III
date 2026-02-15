import SwiftUI

struct FavoritesView: View {
    @Binding var favoriteTargetIds: Set<String>
    @Binding var selectedTargets: [Target]
    var maxTargets: Int = 6

    @Environment(\.dismiss) private var dismiss
    @State private var wikiTarget: Target?
    private let dataManager = DataManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if favoriteTargets.isEmpty {
                    emptyState
                } else {
                    favoritesList
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $wikiTarget) { target in
                WikipediaImageView(target: target)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No favorites yet")
                .font(.headline)
            Text("Tap the star icon in the target picker to save targets for later")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var favoritesList: some View {
        List {
            ForEach(groupedFavorites, id: \.0) { type, targets in
                Section(header: Text(type)) {
                    ForEach(targets) { target in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
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

                            if isSelected(target) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            } else {
                                Button {
                                    addToTargets(target)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedTargets.count >= maxTargets)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                favoriteTargetIds.remove(target.id)
                            } label: {
                                Label("Remove", systemImage: "star.slash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var favoriteTargets: [Target] {
        dataManager.targets.filter { favoriteTargetIds.contains($0.id) }
    }

    private var groupedFavorites: [(String, [Target])] {
        Dictionary(grouping: favoriteTargets, by: { $0.type })
            .sorted { $0.key < $1.key }
    }

    private func isSelected(_ target: Target) -> Bool {
        selectedTargets.contains { $0.id == target.id }
    }

    private func addToTargets(_ target: Target) {
        guard selectedTargets.count < maxTargets,
              !isSelected(target) else { return }
        selectedTargets.append(target)
    }
}
