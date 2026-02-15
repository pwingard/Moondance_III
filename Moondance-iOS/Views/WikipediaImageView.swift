import SwiftUI

struct WikipediaImageView: View {
    let target: Target
    @Environment(\.dismiss) private var dismiss

    @State private var summary: WikipediaSummary?
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingState
                } else if let summary = summary {
                    contentView(summary)
                } else {
                    failedState
                }
            }
            .navigationTitle(target.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            let result = await WikipediaService.fetchSummary(for: target)
            summary = result
            isLoading = false
            failed = result == nil
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading from Wikipedia...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No image available")
                .font(.headline)
            Text("Wikipedia doesn't have an image for this object")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func contentView(_ summary: WikipediaSummary) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if let imageUrl = summary.originalimage?.source ?? summary.thumbnail?.source,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                        case .failure:
                            imagePlaceholder
                        case .empty:
                            ProgressView()
                                .frame(height: 250)
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                }

                if let extract = summary.extract, !extract.isEmpty {
                    Text(extract)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let pageUrl = summary.contentUrls?.mobile?.page,
                   let url = URL(string: pageUrl) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text("View on Wikipedia")
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 200)
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
    }
}
