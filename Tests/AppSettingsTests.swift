import XCTest
import AVFoundation
@testable import Radcap

final class AppSettingsTests: XCTestCase {

    // MARK: - AudioFormat

    func testAudioFormatFileExtensions() {
        XCTAssertEqual(AppSettings.AudioFormat.m4a.fileExtension, "m4a")
        XCTAssertEqual(AppSettings.AudioFormat.wav.fileExtension, "wav")
    }

    func testAudioFormatAVFileTypes() {
        XCTAssertEqual(AppSettings.AudioFormat.m4a.avFileType, .m4a)
        XCTAssertEqual(AppSettings.AudioFormat.wav.avFileType, .wav)
    }

    // MARK: - VideoFormat

    func testVideoFormatFileExtensions() {
        XCTAssertEqual(AppSettings.VideoFormat.mov.fileExtension, "mov")
        XCTAssertEqual(AppSettings.VideoFormat.mp4.fileExtension, "mp4")
    }

    func testVideoFormatAVFileTypes() {
        XCTAssertEqual(AppSettings.VideoFormat.mov.avFileType, .mov)
        XCTAssertEqual(AppSettings.VideoFormat.mp4.avFileType, .mp4)
    }

    // MARK: - effectiveOutputDirectory fallback

    func testEffectiveOutputDirectoryUsesExplicitDirectoryWhenSet() throws {
        let saved = AppSettings.shared.outputDirectory
        defer { AppSettings.shared.outputDirectory = saved }

        let tempDir = FileManager.default.temporaryDirectory
        AppSettings.shared.outputDirectory = tempDir
        XCTAssertEqual(AppSettings.shared.effectiveOutputDirectory, tempDir)
    }

    func testEffectiveOutputDirectoryFallsBackWhenNil() throws {
        let saved = AppSettings.shared.outputDirectory
        defer { AppSettings.shared.outputDirectory = saved }

        AppSettings.shared.outputDirectory = nil
        let expectedSearch: FileManager.SearchPathDirectory =
            AppSettings.isSandboxed ? .moviesDirectory : .desktopDirectory
        let expected = FileManager.default.urls(for: expectedSearch, in: .userDomainMask)[0]
        XCTAssertEqual(AppSettings.shared.effectiveOutputDirectory, expected)
    }

    // MARK: - Persisted setting round-trips

    func testTeleprompterSpeedRoundTrip() {
        let saved = AppSettings.shared.teleprompterSpeed
        defer { AppSettings.shared.teleprompterSpeed = saved }

        AppSettings.shared.teleprompterSpeed = 1.25
        XCTAssertEqual(AppSettings.shared.teleprompterSpeed, 1.25)
        XCTAssertEqual(UserDefaults.standard.double(forKey: "teleprompterSpeed"), 1.25)
    }

    func testVideoFormatRoundTrip() {
        let saved = AppSettings.shared.videoFormat
        defer { AppSettings.shared.videoFormat = saved }

        AppSettings.shared.videoFormat = .mp4
        XCTAssertEqual(AppSettings.shared.videoFormat, .mp4)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "videoFormat"), AppSettings.VideoFormat.mp4.rawValue)
    }
}
