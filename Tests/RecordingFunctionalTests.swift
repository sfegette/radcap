import XCTest
import AVFoundation
import Combine
@testable import Radcap

/// Recording pipeline tests.
///
/// - `testAudioWriterInputWithNilSettingsDoesNotCrash` — hardware-free; tests the
///   nil-fallback branch of the v1.0.3 crash fix.
/// - `testRecordMOVClipWithAudio` / `testRecordMP4ClipWithAudio` — require camera +
///   microphone access; run on a developer Mac (the test bundle uses Radcap.app as its
///   host via TEST_HOST so it inherits the app's entitlements).
final class RecordingFunctionalTests: XCTestCase {

    // MARK: - Crash-regression test (no hardware required)

    /// Regression for the v1.0.3 crash.
    ///
    /// `AVAssetWriterInput(mediaType:outputSettings:)` is an ObjC initializer that throws
    /// an NSException (not a Swift error) when settings are invalid for the container —
    /// Swift cannot catch this, so it becomes a hard SIGABRT.  The fix replaced hardcoded
    /// LPCM/AAC settings with `recommendedAudioSettingsForAssetWriter(writingTo:)`.
    ///
    /// A bare `AVCaptureAudioDataOutput` (not attached to a session) returns `nil` from
    /// that call — the passthrough case.  This test verifies that passing `nil` settings to
    /// `AVAssetWriterInput` does *not* throw, and that `writer.canAdd()` correctly gates
    /// containers that can't accept passthrough PCM (MP4) so production always fails
    /// gracefully rather than crashing.
    ///
    /// The happy path (connected session returning real codec settings) is exercised by
    /// `testRecordMOVClipWithAudio` and `testRecordMP4ClipWithAudio`.
    func testAudioWriterInputWithNilSettingsDoesNotCrash() throws {
        let audioOutput = AVCaptureAudioDataOutput()
        let tempDir = FileManager.default.temporaryDirectory

        // MOV accepts passthrough audio — canAdd should be true.
        let movURL = tempDir.appendingPathComponent("\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: movURL) }
        let movWriter = try XCTUnwrap(try? AVAssetWriter(outputURL: movURL, fileType: .mov))
        let movSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
        // If this line throws NSException the process crashes — that is the regression signal.
        let movInput = AVAssetWriterInput(mediaType: .audio, outputSettings: movSettings)
        XCTAssertTrue(movWriter.canAdd(movInput),
                      ".mov should accept a nil-settings (passthrough) audio input")

        // MP4 requires compressed audio — canAdd should be false for nil/passthrough settings,
        // which is the graceful-failure path in startRecording().
        let mp4URL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: mp4URL) }
        let mp4Writer = try XCTUnwrap(try? AVAssetWriter(outputURL: mp4URL, fileType: .mp4))
        let mp4Settings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4)
        let mp4Input = AVAssetWriterInput(mediaType: .audio, outputSettings: mp4Settings)
        XCTAssertFalse(mp4Writer.canAdd(mp4Input),
                       ".mp4 should reject nil/passthrough audio — graceful canAdd gate must hold")
    }

    // MARK: - Functional recording tests (requires camera + microphone access)

    func testRecordMOVClipWithAudio() throws {
        try recordAndVerify(videoFormat: .mov)
    }

    func testRecordMP4ClipWithAudio() throws {
        try recordAndVerify(videoFormat: .mp4)
    }

    // MARK: - Helper

    private func recordAndVerify(videoFormat: AppSettings.VideoFormat) throws {
        let savedFormat = AppSettings.shared.videoFormat
        defer { AppSettings.shared.videoFormat = savedFormat }
        AppSettings.shared.videoFormat = videoFormat

        // Write to a known temp path so the file-search can't pick up a stale clip.
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RadcapTest_\(videoFormat.fileExtension)_\(UUID().uuidString).\(videoFormat.fileExtension)")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        AppSettings.shared.outputDirectory = outputURL.deletingLastPathComponent()

        let manager = CaptureManager()
        // Safety net: stop recording if the test throws after startRecording() succeeds.
        defer { if manager.isRecording { manager.stopRecording() } }

        // Wait for the capture session (includes any permission prompts on first run).
        let sessionReady = XCTestExpectation(description: "capture session running")
        var sessionSub: AnyCancellable? = manager.$sessionRunning
            .filter { $0 }.prefix(1)
            .sink { _ in sessionReady.fulfill() }
        wait(for: [sessionReady], timeout: 20)
        sessionSub = nil

        XCTAssertTrue(
            manager.startRecording(),
            "startRecording() returned false for \(videoFormat.rawValue) — check camera/mic permissions"
        )

        Thread.sleep(forTimeInterval: 3)   // record for 3 seconds
        manager.stopRecording()

        // Wait for AVAssetWriter.finishWriting to complete.
        let finalized = XCTestExpectation(description: "recording finalized")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { finalized.fulfill() }
        wait(for: [finalized], timeout: 8)

        // Verify the clip has non-empty audio and video tracks.
        let asset = AVURLAsset(url: outputURL)
        let tracksChecked = XCTestExpectation(description: "asset tracks checked")
        Task {
            let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
            let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
            let duration    = (try? await asset.load(.duration)) ?? .zero

            XCTAssertFalse(audioTracks.isEmpty,
                           "No audio track in \(outputURL.lastPathComponent)")
            XCTAssertFalse(videoTracks.isEmpty,
                           "No video track in \(outputURL.lastPathComponent)")
            XCTAssertGreaterThan(CMTimeGetSeconds(duration), 1.0,
                                 "Duration too short — \(outputURL.lastPathComponent)")

            // Verify audio track has actual sample data (not just an empty track shell).
            if let audioTrack = audioTracks.first {
                let segments = (try? await audioTrack.load(.segments)) ?? []
                let hassamples = segments.contains { !$0.isEmpty }
                XCTAssertTrue(hassamples,
                              "Audio track exists but contains no samples — silent file detected")
            }

            tracksChecked.fulfill()
        }
        wait(for: [tracksChecked], timeout: 10)
    }
}
