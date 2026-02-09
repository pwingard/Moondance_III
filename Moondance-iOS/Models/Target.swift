import Foundation

struct Target: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let ra: Double
    let dec: Double
    let magnitude: Double?
    let size: String
}

struct TargetsData: Codable {
    let targets: [Target]
}
