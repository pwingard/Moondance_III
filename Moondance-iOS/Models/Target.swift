import Foundation

struct Target: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let ra: Double
    let dec: Double
    let magnitude: Double?
    let surfaceBrightness: Double?
    let size: String

    enum CodingKeys: String, CodingKey {
        case id, name, type, ra, dec, magnitude, surfaceBrightness, size
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(String.self, forKey: .type)
        ra = try c.decode(Double.self, forKey: .ra)
        dec = try c.decode(Double.self, forKey: .dec)
        magnitude = try c.decodeIfPresent(Double.self, forKey: .magnitude)
        surfaceBrightness = try c.decodeIfPresent(Double.self, forKey: .surfaceBrightness)
        size = try c.decode(String.self, forKey: .size)
    }

    init(id: String, name: String, type: String, ra: Double, dec: Double,
         magnitude: Double?, surfaceBrightness: Double?, size: String) {
        self.id = id; self.name = name; self.type = type
        self.ra = ra; self.dec = dec
        self.magnitude = magnitude; self.surfaceBrightness = surfaceBrightness
        self.size = size
    }

    /// Display string for brightness — "Mag X.X", "SB X.X", or "—"
    var brightnessLabel: String {
        if let mag = magnitude { return "Mag \(String(format: "%.1f", mag))" }
        if let sb = surfaceBrightness { return "SB \(String(format: "%.1f", sb))" }
        return "—"
    }
}

struct TargetsData: Codable {
    let targets: [Target]
}
