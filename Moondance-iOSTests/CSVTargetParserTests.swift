import Testing
import Foundation
@testable import Moondance_iOS

@Suite("CSVTargetParser")
struct CSVTargetParserTests {

    // MARK: - Basic parsing

    @Test func parsesThreeColumnRow() {
        let csv = "Orion Nebula,83.82,-5.39"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 1)
        #expect(result.skippedCount == 0)
        let t = result.imported[0]
        #expect(t.name == "Orion Nebula")
        #expect(abs(t.ra - 83.82) < 0.001)
        #expect(abs(t.dec - (-5.39)) < 0.001)
        #expect(t.type == "Custom")
    }

    @Test func parsesFiveColumnRow() {
        let csv = "M42,83.82,-5.39,4.0,65x60"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 1)
        let t = result.imported[0]
        #expect(t.magnitude == 4.0)
        #expect(t.size == "65x60")
    }

    @Test func parsesMultipleRows() {
        let csv = """
        target A,83.82,-5.39
        target B,10.68,41.27
        target C,283.4,33.03
        """
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 3)
        #expect(result.skippedCount == 0)
    }

    // MARK: - Header detection

    @Test func skipsHeaderRow() {
        let csv = """
        Name,RA,Dec
        Orion Nebula,83.82,-5.39
        """
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 1)
        #expect(result.imported[0].name == "Orion Nebula")
    }

    @Test func doesNotSkipDataRowWhenNoHeader() {
        // First row has numeric RA — should not be treated as header
        let csv = """
        Rosette,98.0,4.9
        Seagull,107.1,-10.4
        """
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 2)
    }

    // MARK: - Line endings

    @Test func handlesCRLFLineEndings() {
        let csv = "target A,83.82,-5.39\r\ntarget B,10.68,41.27\r\ntarget C,283.4,33.03"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 3, "All 3 rows should parse with \\r\\n line endings")
    }

    @Test func handlesCROnlyLineEndings() {
        let csv = "target A,83.82,-5.39\rtarget B,10.68,41.27\rtarget C,283.4,33.03"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 3, "All 3 rows should parse with \\r-only line endings")
    }

    @Test func handlesMixedLineEndings() {
        let csv = "target A,83.82,-5.39\r\ntarget B,10.68,41.27\ntarget C,283.4,33.03"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 3)
    }

    // MARK: - Quoted fields

    @Test func parsesQuotedNameWithComma() {
        let csv = "\"Flame, Orion\",85.25,-1.85"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 1)
        #expect(result.imported[0].name == "Flame, Orion")
    }

    @Test func parsesEscapedQuoteInName() {
        let csv = "\"Star\"\"s Rest\",83.82,-5.39"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 1)
    }

    // MARK: - Validation

    @Test func skipsRowWithTooFewColumns() {
        let csv = "OnlyOneName"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 0)
        #expect(result.skippedCount == 1)
        #expect(result.skippedRows[0].reason.contains("column"))
    }

    @Test func skipsRowWithNonNumericRA() {
        // First row must have a numeric RA so header-detection doesn't eat it.
        // The second row has non-numeric RA and should land in skippedRows.
        let csv = "GoodTarget,83.82,-5.39\nBadTarget,notanumber,-5.39"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 1)
        #expect(result.skippedRows.count == 1)
        #expect(result.skippedRows[0].reason.contains("RA"))
    }

    @Test func skipsRowWithNonNumericDec() {
        let csv = "BadTarget,83.82,notadec"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.skippedRows[0].reason.contains("Dec"))
    }

    @Test func skipsRowWithRAOutOfRange() {
        let csv = "BadTarget,400.0,-5.39"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.skippedRows[0].reason.contains("RA"))
    }

    @Test func skipsRowWithDecOutOfRange() {
        let csv = "BadTarget,83.82,-95.0"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.skippedRows[0].reason.contains("Dec"))
    }

    @Test func acceptsBoundaryValues() {
        // RA=0 and 360, Dec=-90 and 90 are all valid
        let csv = """
        min,0.0,-90.0
        max,360.0,90.0
        """
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 2)
    }

    @Test func reportsRowNumberInSkipReason() {
        let csv = """
        good,83.82,-5.39
        bad,999.0,-5.39
        good2,10.68,41.27
        """
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 2)
        #expect(result.skippedRows[0].row == 2)
    }

    @Test func generatesNameForEmptyNameField() {
        let csv = ",83.82,-5.39"
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 1)
        #expect(result.imported[0].name.contains("Custom"))
    }

    // MARK: - Export / round-trip

    @Test func exportProducesValidCSV() {
        let target = Target(id: "t1", name: "Test", type: "Custom",
                            ra: 83.82, dec: -5.39, magnitude: 4.0,
                            surfaceBrightness: nil, size: "30x30")
        let csv = CSVTargetParser.export([target])
        #expect(csv.contains("Test"))
        #expect(csv.contains("83.82"))
        #expect(csv.contains("-5.39"))
    }

    @Test func exportRoundTrip() {
        let original = [
            Target(id: "t1", name: "Orion Nebula", type: "Custom",
                   ra: 83.82, dec: -5.39, magnitude: 4.0, surfaceBrightness: nil, size: "65x60"),
            Target(id: "t2", name: "Andromeda, M31", type: "Custom",
                   ra: 10.68, dec: 41.27, magnitude: 3.4, surfaceBrightness: nil, size: "180x60")
        ]
        let csv = CSVTargetParser.export(original)
        let result = CSVTargetParser.parse(csv.data(using: .utf8)!)
        #expect(result.imported.count == 2)
        #expect(result.imported[0].name == "Orion Nebula")
        #expect(result.imported[1].name == "Andromeda, M31")  // comma in name survives
        #expect(abs(result.imported[0].ra - 83.82) < 0.001)
        #expect(abs(result.imported[1].dec - 41.27) < 0.001)
    }

    @Test func exportIncludesHeader() {
        let csv = CSVTargetParser.export([])
        #expect(csv.hasPrefix("Name,"))
    }

    @Test func emptyDataReturnsEmpty() {
        let result = CSVTargetParser.parse(Data())
        #expect(result.imported.isEmpty)
        #expect(result.skippedCount == 0)
    }
}
