import AVFoundation
import Combine
import CoreMedia
import CoreVideo
import AppKit

final class CaptureManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var availableMicrophones: [AVCaptureDevice] = []
    @Published var selectedCamera: AVCaptureDevice?
    @Published var selectedMicrophone: AVCaptureDevice?
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var cropMode: CropMode = .none
    @Published var recordingMode: RecordingMode = .videoAndAudio
    @Published var audioFormat: AudioFormat = .m4a
    @Published var sessionRunning = false
    @Published var lastError: String?
    @Published var isSpeaking = false
    private(set) var windowVisible = false

    private var speakingHoldTimer: Timer?
    private let speechThreshold: Float = 0.008   // RMS ≈ -42 dBFS

    // MARK: - Capture Session (session-queue only)

    let captureSession = AVCaptureSession()
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentAudioInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.sfegette.radcap.session", qos: .userInitiated)
    private let outputQueue  = DispatchQueue(label: "com.sfegette.radcap.output",  qos: .userInitiated)

    // MARK: - Recording State (output-queue only)

    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStarted = false
    private var isRecordingInternal = false
    private var activeCropRect: CGRect = .zero

    private var durationTimer: Timer?

    // MARK: - Types

    enum CropMode: String, CaseIterable, Identifiable {
        case none     = "Full Frame"
        case square   = "Square (1:1)"
        case vertical = "Vertical (9:16)"
        var id: String { rawValue }
    }

    enum RecordingMode: String, CaseIterable, Identifiable {
        case videoAndAudio = "Video + Audio"
        case audioOnly     = "Audio Only"
        var id: String { rawValue }
    }

    enum AudioFormat: String, CaseIterable, Identifiable {
        case m4a = "M4A (AAC)"
        case wav = "WAV (Lossless)"
        var id: String { rawValue }
        var fileExtension: String { self == .m4a ? "m4a" : "wav" }
        var avFileType: AVFileType  { self == .m4a ? .m4a  : .wav  }
    }

    // MARK: - Init

    override init() {
        super.init()
        requestPermissionsAndConfigure()
    }

    // MARK: - Permissions

    private func requestPermissionsAndConfigure() {
        let group = DispatchGroup()

        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            group.enter()
            AVCaptureDevice.requestAccess(for: .video) { _ in group.leave() }
        }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            group.enter()
            AVCaptureDevice.requestAccess(for: .audio) { _ in group.leave() }
        }

        group.notify(queue: .main) { [weak self] in
            self?.discoverDevices()
            self?.configureSession()
        }
    }

    // MARK: - Device Discovery

    func discoverDevices() {
        let videoTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .continuityCamera,
            .deskViewCamera,
            .external
        ]
        let cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: videoTypes, mediaType: .video, position: .unspecified
        ).devices

        let micTypes: [AVCaptureDevice.DeviceType] = [
            .microphone,
            .external
        ]
        let mics = AVCaptureDevice.DiscoverySession(
            deviceTypes: micTypes, mediaType: .audio, position: .unspecified
        ).devices

        // Already called on main thread; set synchronously so configureSession()
        // sees the devices when it dispatches to sessionQueue immediately after.
        availableCameras = cameras
        if selectedCamera == nil {
            selectedCamera = AVCaptureDevice.default(for: .video) ?? cameras.first
        }
        availableMicrophones = mics
        if selectedMicrophone == nil {
            selectedMicrophone = AVCaptureDevice.default(for: .audio) ?? mics.first
        }
    }

    // MARK: - Session Lifecycle

    func setWindowVisible(_ visible: Bool) {
        windowVisible = visible
        updateSessionState()
    }

    private func updateSessionState() {
        let shouldRun = windowVisible || isRecording
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if shouldRun {
                if !self.captureSession.isRunning { self.captureSession.startRunning() }
            } else {
                if self.captureSession.isRunning { self.captureSession.stopRunning() }
            }
            DispatchQueue.main.async { self.sessionRunning = self.captureSession.isRunning }
        }
    }

    // MARK: - Session Configuration

    func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            if let camera = self.selectedCamera,
               let input = try? AVCaptureDeviceInput(device: camera),
               self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                self.currentVideoInput = input
            }

            if let mic = self.selectedMicrophone,
               let input = try? AVCaptureDeviceInput(device: mic),
               self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                self.currentAudioInput = input
            }

            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.outputQueue)
            if self.captureSession.canAddOutput(self.videoDataOutput) {
                self.captureSession.addOutput(self.videoDataOutput)
            }

            self.audioDataOutput.setSampleBufferDelegate(self, queue: self.outputQueue)
            if self.captureSession.canAddOutput(self.audioDataOutput) {
                self.captureSession.addOutput(self.audioDataOutput)
            }

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()

            DispatchQueue.main.async {
                self.sessionRunning = self.captureSession.isRunning
            }
        }
    }

    // MARK: - Device Switching

    func switchCamera(to device: AVCaptureDevice) {
        DispatchQueue.main.async { self.selectedCamera = device }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            if let old = self.currentVideoInput { self.captureSession.removeInput(old) }
            if let input = try? AVCaptureDeviceInput(device: device),
               self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                self.currentVideoInput = input
            }
            self.captureSession.commitConfiguration()
        }
    }

    func switchMicrophone(to device: AVCaptureDevice) {
        DispatchQueue.main.async { self.selectedMicrophone = device }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            if let old = self.currentAudioInput { self.captureSession.removeInput(old) }
            if let input = try? AVCaptureDeviceInput(device: device),
               self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                self.currentAudioInput = input
            }
            self.captureSession.commitConfiguration()
        }
    }

    // MARK: - Recording

    func toggleRecording() { isRecording ? stopRecording() : startRecording() }

    func startRecording() {
        guard !isRecording else { return }

        let sourceDims: CMVideoDimensions
        if let camera = selectedCamera {
            sourceDims = CMVideoFormatDescriptionGetDimensions(camera.activeFormat.formatDescription)
        } else {
            sourceDims = CMVideoDimensions(width: 1280, height: 720)
        }
        let outDims  = croppedDimensions(from: sourceDims, mode: cropMode)
        let cropRect = makeCropRect(source: sourceDims, output: outDims)

        let outputURL = generateOutputURL()
        let fileType: AVFileType = recordingMode == .audioOnly ? audioFormat.avFileType : .mov

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: fileType) else {
            DispatchQueue.main.async { self.lastError = "Could not create output file at \(outputURL.path)." }
            return
        }

        // Video writer input
        var vInput: AVAssetWriterInput?
        var adaptor: AVAssetWriterInputPixelBufferAdaptor?

        if recordingMode == .videoAndAudio {
            let vSettings: [String: Any] = [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  Int(outDims.width),
                AVVideoHeightKey: Int(outDims.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey:       10_000_000,
                    AVVideoProfileLevelKey:          AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey:   30
                ] as [String: Any]
            ]
            let vi = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
            vi.expectsMediaDataInRealTime = true
            if writer.canAdd(vi) {
                writer.add(vi)
                vInput = vi
                let pixelAttrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey  as String: Int(outDims.width),
                    kCVPixelBufferHeightKey as String: Int(outDims.height)
                ]
                adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: vi,
                    sourcePixelBufferAttributes: pixelAttrs
                )
            }
        }

        // Audio writer input
        let aSettings: [String: Any]
        if audioFormat == .wav {
            aSettings = [
                AVFormatIDKey:                kAudioFormatLinearPCM,
                AVSampleRateKey:              44100.0,
                AVNumberOfChannelsKey:        2,
                AVLinearPCMBitDepthKey:    32,
                AVLinearPCMIsFloatKey:     true,
                AVLinearPCMIsBigEndianKey: false
            ]
        } else {
            aSettings = [
                AVFormatIDKey:          kAudioFormatMPEG4AAC,
                AVSampleRateKey:        44100.0,
                AVNumberOfChannelsKey:  2,
                AVEncoderBitRateKey:    256_000
            ]
        }
        let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
        ai.expectsMediaDataInRealTime = true
        if writer.canAdd(ai) { writer.add(ai) }

        writer.startWriting()

        outputQueue.async { [weak self] in
            guard let self else { return }
            self.assetWriter        = writer
            self.videoWriterInput   = vInput
            self.audioWriterInput   = ai
            self.pixelBufferAdaptor = adaptor
            self.activeCropRect     = cropRect
            self.sessionStarted     = false
            self.isRecordingInternal = true
        }

        isRecording = true
        updateSessionState()
        recordingDuration = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        updateSessionState()
        durationTimer?.invalidate()
        durationTimer = nil
        speakingHoldTimer?.invalidate()
        speakingHoldTimer = nil
        isSpeaking = false

        outputQueue.async { [weak self] in
            guard let self else { return }
            self.isRecordingInternal = false
            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()
            let writer = self.assetWriter
            self.assetWriter        = nil
            self.videoWriterInput   = nil
            self.audioWriterInput   = nil
            self.pixelBufferAdaptor = nil
            self.sessionStarted     = false
            writer?.finishWriting {}
        }
    }

    // MARK: - Helpers

    private func croppedDimensions(from src: CMVideoDimensions, mode: CropMode) -> CMVideoDimensions {
        let w = src.width, h = src.height
        switch mode {
        case .none:     return src
        case .square:
            let side = min(w, h)
            return CMVideoDimensions(width: side, height: side)
        case .vertical:
            let tw = Int32(Double(h) * 9.0 / 16.0)
            if tw <= w { return CMVideoDimensions(width: tw, height: h) }
            let th = Int32(Double(w) * 16.0 / 9.0)
            return CMVideoDimensions(width: w, height: min(th, h))
        }
    }

    private func makeCropRect(source src: CMVideoDimensions, output out: CMVideoDimensions) -> CGRect {
        CGRect(
            x: CGFloat(src.width  - out.width)  / 2,
            y: CGFloat(src.height - out.height) / 2,
            width: CGFloat(out.width),
            height: CGFloat(out.height)
        )
    }

    private func generateOutputURL() -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmmss"
        let ext = recordingMode == .audioOnly ? audioFormat.fileExtension : "mov"
        let name = "Radcap_\(fmt.string(from: Date())).\(ext)"
        return AppSettings.shared.effectiveOutputDirectory.appendingPathComponent(name)
    }

    var durationString: String {
        let t = Int(recordingDuration)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Pixel Buffer Crop

    private func cropPixelBuffer(_ src: CVPixelBuffer, to rect: CGRect) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(src, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(src, .readOnly) }

        guard let srcBase = CVPixelBufferGetBaseAddress(src) else { return nil }

        let srcW   = CVPixelBufferGetWidth(src)
        let srcH   = CVPixelBufferGetHeight(src)
        let srcBPR = CVPixelBufferGetBytesPerRow(src)
        let fmt    = CVPixelBufferGetPixelFormatType(src)

        let cx = max(0, Int(rect.origin.x))
        let cy = max(0, Int(rect.origin.y))
        let cw = min(Int(rect.width),  srcW - cx)
        let ch = min(Int(rect.height), srcH - cy)
        guard cw > 0, ch > 0 else { return nil }

        var dst: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, cw, ch, fmt, nil, &dst) == kCVReturnSuccess,
              let dst else { return nil }

        CVPixelBufferLockBaseAddress(dst, [])
        defer { CVPixelBufferUnlockBaseAddress(dst, []) }
        guard let dstBase = CVPixelBufferGetBaseAddress(dst) else { return nil }
        let dstBPR = CVPixelBufferGetBytesPerRow(dst)

        for row in 0..<ch {
            memcpy(
                dstBase.advanced(by: row * dstBPR),
                srcBase.advanced(by: (cy + row) * srcBPR + cx * 4),
                cw * 4
            )
        }
        return dst
    }
}

// MARK: - Sample Buffer Delegates

extension CaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate,
                           AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // Voice detection runs whenever audio is flowing — independent of
        // recording state so the voice gate works even if the writer fails.
        if output === audioDataOutput {
            measureAudioLevel(sampleBuffer)
        }

        guard isRecordingInternal,
              let writer = assetWriter,
              writer.status == .writing else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if !sessionStarted {
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
        }

        if output === videoDataOutput {
            guard recordingMode == .videoAndAudio,
                  let vInput = videoWriterInput,
                  vInput.isReadyForMoreMediaData else { return }

            if cropMode == .none {
                vInput.append(sampleBuffer)
            } else if let adaptor = pixelBufferAdaptor,
                      adaptor.assetWriterInput.isReadyForMoreMediaData,
                      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                      let cropped = cropPixelBuffer(imageBuffer, to: activeCropRect) {
                adaptor.append(cropped, withPresentationTime: pts)
            } else {
                vInput.append(sampleBuffer)
            }

        } else if output === audioDataOutput {
            guard let aInput = audioWriterInput,
                  aInput.isReadyForMoreMediaData else { return }
            aInput.append(sampleBuffer)
        }
    }

    // Called on outputQueue — dispatches result to main thread.
    private func measureAudioLevel(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee,
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0,
                                    lengthAtOffsetOut: nil,
                                    totalLengthOut: &totalLength,
                                    dataPointerOut: &dataPointer)
        guard let ptr = dataPointer, totalLength > 0 else { return }

        let raw = UnsafeRawPointer(ptr)
        var sumSq: Double = 0
        var sampleCount = 0

        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0, asbd.mBitsPerChannel == 32 {
            let count = totalLength / 4
            let samples = UnsafeBufferPointer(start: raw.assumingMemoryBound(to: Float32.self), count: count)
            for s in samples { sumSq += Double(s) * Double(s) }
            sampleCount = count
        } else if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0, asbd.mBitsPerChannel == 64 {
            let count = totalLength / 8
            let samples = UnsafeBufferPointer(start: raw.assumingMemoryBound(to: Float64.self), count: count)
            for s in samples { sumSq += s * s }
            sampleCount = count
        } else if asbd.mBitsPerChannel == 16 {
            let count = totalLength / 2
            let samples = UnsafeBufferPointer(start: raw.assumingMemoryBound(to: Int16.self), count: count)
            let scale = 1.0 / Double(Int16.max)
            for s in samples { let f = Double(s) * scale; sumSq += f * f }
            sampleCount = count
        } else if asbd.mBitsPerChannel == 32 {
            let count = totalLength / 4
            let samples = UnsafeBufferPointer(start: raw.assumingMemoryBound(to: Int32.self), count: count)
            let scale = 1.0 / Double(Int32.max)
            for s in samples { let f = Double(s) * scale; sumSq += f * f }
            sampleCount = count
        }

        guard sampleCount > 0 else { return }
        let rms = Float(sqrt(sumSq / Double(sampleCount)))
        guard rms.isFinite else { return }
        DispatchQueue.main.async { [weak self] in self?.updateSpeakingState(rms: rms) }
    }

    // Hold "speaking" for 400ms after audio drops below threshold to smooth
    // over natural breath gaps and brief mid-sentence pauses.
    private func updateSpeakingState(rms: Float) {
        if rms > speechThreshold {
            speakingHoldTimer?.invalidate()
            speakingHoldTimer = nil
            if !isSpeaking { isSpeaking = true }
        } else if isSpeaking, speakingHoldTimer == nil {
            speakingHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                self?.isSpeaking = false
                self?.speakingHoldTimer = nil
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {}
}
