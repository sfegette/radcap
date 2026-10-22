import XCTest
@testable import Radcap

final class DiagnosticsReportTests: XCTestCase {
    func testReportListsVersionsAndErrorLines() {
        let report = DiagnosticsReport.build(errorLines: ["2026-01-01T00:00:00Z [CaptureManager] Mic access denied"])
        XCTAssertTrue(report.contains("Radcap diagnostics"))
        XCTAssertTrue(report.contains("macOS:"))
        XCTAssertTrue(report.contains("Mic access denied"))
    }

    func testReportWithoutErrorsSaysNone() {
        XCTAssertTrue(DiagnosticsReport.build(errorLines: []).contains("none"))
    }
}
