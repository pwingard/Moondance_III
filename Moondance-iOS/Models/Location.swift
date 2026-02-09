import Foundation

struct Location: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let elevation: Double
    let timezone: String
}

struct LocationsData: Codable {
    let locations: [Location]
}
