import Foundation

class DataManager {
    static let shared = DataManager()

    let targets: [Target]
    let locations: [Location]

    /// Targets grouped by type for picker display
    var targetsByType: [String: [Target]] {
        Dictionary(grouping: targets, by: { $0.type })
    }

    private init() {
        targets = Self.loadJSON(filename: "targets", type: TargetsData.self)?.targets ?? []
        locations = Self.loadJSON(filename: "locations", type: LocationsData.self)?.locations ?? []
    }

    private static func loadJSON<T: Codable>(filename: String, type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("Could not find \(filename).json in bundle")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Error loading \(filename).json: \(error)")
            return nil
        }
    }
}
