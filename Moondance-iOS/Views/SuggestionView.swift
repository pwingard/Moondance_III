import SwiftUI

struct SuggestionView: View {
    let suggestions: [TargetSuggestion]
    let selectedCount: Int
    let maxTargets: Int
    var onAdd: (Target) -> Void = { _ in }
    var onRemove: (Target) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var addedIds: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if suggestions.isEmpty {
                    emptyState
                } else {
                    suggestionList
                }
            }
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.green)
            Text("Your targets cover the night well")
                .font(.headline)
            Text("No significant gaps to fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionList: some View {
        List {
            Section {
                Text("Targets that fill unused time in your night")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(suggestions) { suggestion in
                HStack(spacing: 12) {
                    ratingDot(suggestion.rating)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.target.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 4) {
                            Text(suggestion.target.type)
                            if let mag = suggestion.target.magnitude {
                                Text("· Mag \(mag, specifier: "%.1f")")
                            }
                            Text("· \(suggestion.target.size)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Text("\(suggestion.gapCoverageHours, specifier: "%.1f")h in gap · \(suggestion.reason)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        if let avail = suggestion.availableFrom {
                            Text(avail)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.cyan)
                        }
                    }

                    Spacer()

                    if addedIds.contains(suggestion.target.id) {
                        Button {
                            onRemove(suggestion.target)
                            addedIds.remove(suggestion.target.id)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            onAdd(suggestion.target)
                            addedIds.insert(suggestion.target.id)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedCount + addedIds.count >= maxTargets)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func ratingDot(_ rating: MoonTierConfig.ImagingRating) -> some View {
        Circle()
            .fill(ratingColor(rating))
            .frame(width: 10, height: 10)
    }

    private func ratingColor(_ rating: MoonTierConfig.ImagingRating) -> Color {
        switch rating {
        case .good: return .green
        case .allowable: return .yellow
        case .mixed: return .orange
        case .noImaging: return .red
        }
    }
}
