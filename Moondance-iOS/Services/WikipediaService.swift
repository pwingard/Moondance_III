import Foundation

struct WikipediaSummary: Codable {
    let title: String
    let extract: String?
    let thumbnail: WikiImage?
    let originalimage: WikiImage?
    let contentUrls: ContentUrls?

    enum CodingKeys: String, CodingKey {
        case title, extract, thumbnail, originalimage
        case contentUrls = "content_urls"
    }

    struct WikiImage: Codable {
        let source: String
        let width: Int
        let height: Int
    }

    struct ContentUrls: Codable {
        let mobile: PageUrl?

        struct PageUrl: Codable {
            let page: String?
        }
    }
}

struct WikipediaService {

    /// Try to fetch a Wikipedia summary for the given target.
    /// Attempts multiple search terms derived from the target name.
    static func fetchSummary(for target: Target) async -> WikipediaSummary? {
        let searchTerms = buildSearchTerms(from: target)
        for term in searchTerms {
            if let summary = await fetchPage(term: term) {
                return summary
            }
        }
        return nil
    }

    /// Build a list of Wikipedia article title guesses from the target name.
    /// e.g. "M42 - Orion Nebula" → ["Orion Nebula", "Messier 42", "M42"]
    private static func buildSearchTerms(from target: Target) -> [String] {
        var terms: [String] = []

        let parts = target.name.components(separatedBy: " - ")
        if parts.count == 2 {
            let commonName = parts[1].trimmingCharacters(in: .whitespaces)
            // Skip generic names like "Spiral Galaxy" or "Barred Spiral Galaxy"
            let generic = ["spiral galaxy", "barred spiral galaxy", "reflection nebula",
                           "star forming region", "edge-on galaxy", "open cluster",
                           "globular cluster", "planetary nebula"]
            if !generic.contains(commonName.lowercased()) {
                terms.append(commonName)
            }

            let catalogPart = parts[0].trimmingCharacters(in: .whitespaces)
            // Expand M42 → Messier 42, NGC 281 stays as is, IC 1396 stays
            if catalogPart.hasPrefix("M") && catalogPart.count <= 4,
               let num = Int(catalogPart.dropFirst()) {
                terms.append("Messier \(num)")
            }
            terms.append(catalogPart)
        } else {
            terms.append(target.name)
        }

        return terms
    }

    private static func fetchPage(term: String) async -> WikipediaSummary? {
        let encoded = term.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? term
        let urlString = "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let summary = try JSONDecoder().decode(WikipediaSummary.self, from: data)
            // Only return if there's an image
            if summary.thumbnail != nil || summary.originalimage != nil {
                return summary
            }
            return nil
        } catch {
            return nil
        }
    }
}
