import Foundation

struct CSVTargetParser {

    struct ParseResult {
        let imported: [Target]
        let skippedRows: [(row: Int, reason: String)]
        var skippedCount: Int { skippedRows.count }
    }

    /// Parse CSV data into Target objects with type="Custom".
    /// Expected columns: Name, RA (degrees), Dec (degrees) [, Magnitude [, Size]]
    static func parse(_ data: Data) -> ParseResult {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return ParseResult(imported: [], skippedRows: [])
        }

        // Normalize all line endings to \n before splitting
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return ParseResult(imported: [], skippedRows: []) }

        // Skip header row if RA column is non-numeric
        let firstFields = splitCSVLine(lines[0])
        if firstFields.count >= 2, Double(firstFields[1].trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
            lines.removeFirst()
        }

        var imported: [Target] = []
        var skippedRows: [(row: Int, reason: String)] = []

        for (index, line) in lines.enumerated() {
            let rowNum = index + 1
            let fields = splitCSVLine(line)
            guard fields.count >= 3 else {
                skippedRows.append((rowNum, "only \(fields.count) column(s)"))
                continue
            }

            let rawName = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let raStr = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let decStr = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)

            guard let ra = Double(raStr) else {
                skippedRows.append((rowNum, "invalid RA '\(raStr)'"))
                continue
            }
            guard let dec = Double(decStr) else {
                skippedRows.append((rowNum, "invalid Dec '\(decStr)'"))
                continue
            }
            guard (0.0...360.0).contains(ra) else {
                skippedRows.append((rowNum, "RA \(ra) out of range 0–360"))
                continue
            }
            guard (-90.0...90.0).contains(dec) else {
                skippedRows.append((rowNum, "Dec \(dec) out of range –90–90"))
                continue
            }

            let name = rawName.isEmpty
                ? "Custom (\(String(format: "%.4f", ra))°, \(String(format: "%.4f", dec))°)"
                : rawName
            let magnitude: Double? = fields.count >= 4 ? Double(fields[3].trimmingCharacters(in: .whitespacesAndNewlines)) : nil
            let size = fields.count >= 5 ? fields[4].trimmingCharacters(in: .whitespacesAndNewlines) : "—"

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

        return ParseResult(imported: imported, skippedRows: skippedRows)
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
