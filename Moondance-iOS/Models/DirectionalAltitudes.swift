import Foundation

/// The 8 cardinal/intercardinal directions, ordered N, NE, E, SE, S, SW, W, NW
enum CardinalDirection: Int, CaseIterable, Identifiable {
    case N = 0, NE, E, SE, S, SW, W, NW

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .N: return "N"
        case .NE: return "NE"
        case .E: return "E"
        case .SE: return "SE"
        case .S: return "S"
        case .SW: return "SW"
        case .W: return "W"
        case .NW: return "NW"
        }
    }

    /// The azimuth in degrees for this direction
    var azimuth: Double {
        Double(rawValue) * 45.0
    }
}

struct DirectionalAltitudes: Codable, Equatable {
    /// [N, NE, E, SE, S, SW, W, NW] minimum altitudes in degrees
    var values: [Double]

    static let defaultValues = DirectionalAltitudes(
        values: [30, 30, 30, 30, 30, 30, 30, 30]
    )

    /// Interpolated minimum altitude for a given azimuth (0-360 degrees).
    func minimumAltitude(forAzimuth azimuth: Double) -> Double {
        let az = azimuth.truncatingRemainder(dividingBy: 360)
        let normalizedAz = az < 0 ? az + 360 : az

        let sectorIndex = normalizedAz / 45.0
        let lowerIndex = Int(sectorIndex) % 8
        let upperIndex = (lowerIndex + 1) % 8
        let blend = sectorIndex - Double(Int(sectorIndex))

        return values[lowerIndex] * (1.0 - blend) + values[upperIndex] * blend
    }

    var jsonString: String {
        (try? String(data: JSONEncoder().encode(values), encoding: .utf8)) ?? "[30,30,30,30,30,30,30,30]"
    }

    static func from(jsonString: String) -> DirectionalAltitudes {
        guard let data = jsonString.data(using: .utf8),
              let values = try? JSONDecoder().decode([Double].self, from: data),
              values.count == 8
        else { return .defaultValues }
        return DirectionalAltitudes(values: values)
    }
}
