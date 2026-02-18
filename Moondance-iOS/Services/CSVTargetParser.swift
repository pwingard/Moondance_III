import Foundation

struct CSVTargetParser {

    struct ParseResult {
        let imported: [Target]
        let skippedCount: Int
    }

    /// Parse CSV data into Target objects with type="Custom".
    /// Expected columns: Name, RA (degrees), Dec (degrees) [, Magnitude [, Size]]
    static func parse(_ data: Data) -> ParseResult {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return ParseResult(imported: [], skippedCount: 0)
        }

        var lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return ParseResult(imported: [], skippedCount: 0) }

        // Skip header row if RA column is non-numeric
        let firstFields = splitCSVLine(lines[0])
        if firstFields.count >= 2, Double(firstFields[1].trimmingCharacters(in: .whitespaces)) == nil {
            lines.removeFirst()
        }

        var imported: [Target] = []
        var skipped = 0

        for line in lines {
            let fields = splitCSVLine(line)
            guard fields.count >= 3 else { skipped += 1; continue }

            let rawName = fields[0].trimmingCharacters(in: .whitespaces)
            guard let ra  = Double(fields[1].trimmingCharacters(in: .whitespaces)),
                  let dec = Double(fields[2].trimmingCharacters(in: .whitespaces)),
                  (0.0...360.0).contains(ra),
                  (-90.0...90.0).contains(dec) else {
                skipped += 1
                continue
            }

            let name = rawName.isEmpty
                ? "Custom (\(String(format: "%.4f", ra))°, \(String(format: "%.4f", dec))°)"
                : rawName
            let magnitude: Double? = fields.count >= 4 ? Double(fields[3].trimmingCharacters(in: .whitespaces)) : nil
            let size = fields.count >= 5 ? fields[4].trimmingCharacters(in: .whitespaces) : "—"

            imported.append(Target(
                id: "custom_\(UUID().uuidString.prefix(8))",
                name: name,
                type: "Custom",
                ra: ra,
                dec: dec,
                magnitude: magnitude,
                surfaceBrightness: nil,
                size: size.isEmpty ? "—" : size
            ))
        }

        return ParseResult(imported: imported, skippedCount: skipped)
    }

    /// Generate CSV string from targets. Matches import format for round-trip.
    static func export(_ targets: [Target]) -> String {
        var lines = ["Name,RA,Dec,Magnitude,Size"]
        for t in targets {
            let mag = t.magnitude.map { String(format: "%.2f", $0) } ?? ""
            let size = t.size == "—" ? "" : t.size
            let quotedName = "\"\(t.name.replacingOccurrences(of: "\"", with: "\"\""))\""
            lines.append("\(quotedName),\(t.ra),\(t.dec),\(mag),\(size)")
        }
        return lines.joined(separator: "\n")
    }

    // Handles quoted fields containing commas
    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" { inQuotes.toggle() }
            else if char == "," && !inQuotes { fields.append(current); current = "" }
            else { current.append(char) }
        }
        fields.append(current)
        return fields
    }
}
