import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var captureManager: CaptureManager
    @EnvironmentObject var settings: AppSettings
    @State private var showSettings = false
    @State private var teleprompterScrolling = false

    var body: some View {
        VStack(spacing: 0) {
            previewSection
            Divider()
            TeleprompterView(isScrolling: $teleprompterScrolling)
                .frame(maxWidth: .infinity, minHeight: 180)
                .environmentObject(settings)
            Divider()
            controlsSection
        }
        .frame(minWidth: 340, minHeight: 520)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        ZStack(alignment: .topLeading) {
            CameraPreviewView(
                session: captureManager.captureSession,
                cropMode: captureManager.cropMode
            )
            .aspectRatio(previewAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)

            if captureManager.isRecording {
                recordingBadge
            }
        }
    }

    private var previewAspectRatio: CGFloat {
        switch captureManager.cropMode {
        case .none:     return 16.0 / 9.0
        case .square:   return 1.0
        case .vertical: return 9.0 / 16.0
        }
    }

    private var recordingBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
            Text(captureManager.durationString)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 5))
        .padding(8)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 8) {
            // Primary row
            HStack(spacing: 10) {
                recordButton
                Spacer()
                Button {
                    teleprompterScrolling.toggle()
                } label: {
                    Image(systemName: teleprompterScrolling ? "pause.circle" : "play.circle")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .help(teleprompterScrolling ? "Pause teleprompter" : "Auto-scroll teleprompter")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }

            // Device pickers
            HStack(spacing: 8) {
                cameraPicker
                microphonePicker
            }

            // Mode / Crop / Format row
            HStack(spacing: 8) {
                Picker("", selection: $captureManager.recordingMode) {
                    ForEach(CaptureManager.RecordingMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .help("Recording mode")

                Picker("", selection: $captureManager.cropMode) {
                    ForEach(CaptureManager.CropMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .help("Crop mode")

                if captureManager.recordingMode == .audioOnly {
                    Picker("", selection: $captureManager.audioFormat) {
                        ForEach(CaptureManager.AudioFormat.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .help("Audio format")
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
    }

    private var recordButton: some View {
        Button(action: captureManager.toggleRecording) {
            HStack(spacing: 6) {
                Image(systemName: captureManager.isRecording ? "stop.circle.fill" : "record.circle.fill")
                    .foregroundColor(captureManager.isRecording ? .primary : .red)
                Text(captureManager.isRecording ? "Stop" : "Record")
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 90)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .keyboardShortcut("r", modifiers: [.command, .option])
        .disabled(!captureManager.sessionRunning)
    }

    private var cameraPicker: some View {
        Picker("", selection: Binding<AVCaptureDevice?>(
            get: { captureManager.selectedCamera },
            set: { if let d = $0 { captureManager.switchCamera(to: d) } }
        )) {
            ForEach(captureManager.availableCameras, id: \.uniqueID) { cam in
                Text(cam.localizedName).tag(cam as AVCaptureDevice?)
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .help("Select camera")
    }

    private var microphonePicker: some View {
        Picker("", selection: Binding<AVCaptureDevice?>(
            get: { captureManager.selectedMicrophone },
            set: { if let d = $0 { captureManager.switchMicrophone(to: d) } }
        )) {
            ForEach(captureManager.availableMicrophones, id: \.uniqueID) { mic in
                Text(mic.localizedName).tag(mic as AVCaptureDevice?)
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .help("Select microphone")
    }
}
