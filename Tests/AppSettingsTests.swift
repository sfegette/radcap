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

    func testTeleprompterTextIsNotPersistedUnlessEnabled() {
        let settings = AppSettings.shared
        let savedText = settings.teleprompterText
        let savedPreference = settings.savesTeleprompterText
        defer {
            settings.savesTeleprompterText = savedPreference
            settings.teleprompterText = savedText
        }

        settings.savesTeleprompterText = false
        settings.teleprompterText = "Private script"
        XCTAssertNil(UserDefaults.standard.string(forKey: "teleprompterText"))

        settings.savesTeleprompterText = true
        XCTAssertEqual(UserDefaults.standard.string(forKey: "teleprompterText"), "Private script")
    }

    func testClearTeleprompterTextRemovesMemoryAndSavedCopy() {
        let settings = AppSettings.shared
        let savedText = settings.teleprompterText
        let savedPreference = settings.savesTeleprompterText
        defer {
            settings.savesTeleprompterText = savedPreference
            settings.teleprompterText = savedText
        }

        settings.savesTeleprompterText = true
        settings.teleprompterText = "Clear me"
        settings.clearTeleprompterText()

        XCTAssertEqual(settings.teleprompterText, "")
        XCTAssertNil(UserDefaults.standard.string(forKey: "teleprompterText"))
    }

    func testNewInstallKeepsTeleprompterSessionOnly() {
        let defaults = makeIsolatedDefaults()

        XCTAssertEqual(
            AppSettings.teleprompterPersistenceState(defaults: defaults),
            .init(savesText: false, text: "", shouldShowMigrationNotice: false)
        )
        XCTAssertNil(defaults.object(forKey: "savesTeleprompterText"))
    }

    func testLegacySavedTeleprompterTextIsPreservedAndNoticedOnce() {
        let defaults = makeIsolatedDefaults()
        defaults.set("Existing script", forKey: "teleprompterText")

        XCTAssertEqual(
            AppSettings.teleprompterPersistenceState(defaults: defaults),
            .init(savesText: true, text: "Existing script", shouldShowMigrationNotice: true)
        )
        XCTAssertTrue(defaults.bool(forKey: "savesTeleprompterText"))
        XCTAssertEqual(defaults.string(forKey: "teleprompterText"), "Existing script")

        defaults.set(true, forKey: "teleprompterPrivacyNoticeSeen")
        XCTAssertFalse(AppSettings.teleprompterPersistenceState(defaults: defaults).shouldShowMigrationNotice)
    }

    func testExplicitlyDisabledTeleprompterPersistenceDeletesSavedText() {
        let defaults = makeIsolatedDefaults()
        defaults.set(false, forKey: "savesTeleprompterText")
        defaults.set("Remove me", forKey: "teleprompterText")

        XCTAssertEqual(
            AppSettings.teleprompterPersistenceState(defaults: defaults),
            .init(savesText: false, text: "", shouldShowMigrationNotice: false)
        )
        XCTAssertNil(defaults.string(forKey: "teleprompterText"))
    }

    func testOutputDirectoryPreflightAcceptsWritableDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RadcapOutputPreflight-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertNil(CaptureManager.outputDirectoryValidationError(for: directory))
    }

    func testOutputDirectoryPreflightRejectsMissingDirectory() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RadcapMissing-\(UUID().uuidString)")

        XCTAssertEqual(
            CaptureManager.outputDirectoryValidationError(for: directory),
            "The selected recording folder is unavailable."
        )
    }

    func testOutputDirectoryPreflightRejectsFile() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("RadcapNotADirectory-\(UUID().uuidString)")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        XCTAssertEqual(
            CaptureManager.outputDirectoryValidationError(for: file),
            "The selected recording folder is unavailable."
        )
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
