import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var captureManager: CaptureManager
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var coordinator: RecordingCoordinator
    @State private var showSettings = false
    @State private var teleprompterScrolling = false
    @State private var isHoveringClose = false

    let onClose: () -> Void

    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            windowChrome
            previewSection
            Divider()
            TeleprompterView(isScrolling: $teleprompterScrolling)
                .frame(maxWidth: .infinity, minHeight: 180)
                .environmentObject(settings)
            Divider()
            controlsSection
        }
        .frame(minWidth: 340, minHeight: 520)
        .background(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.ultraThinMaterial),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
    }

    // MARK: - Window Chrome

    private var windowChrome: some View {
        HStack {
            Button {
                onClose()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: NSColor(red: 1.0, green: 0.373, blue: 0.341, alpha: 1.0)))
                        .frame(width: 12, height: 12)
                    if isHoveringClose {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                }
            }
            .buttonStyle(.plain)
            .onHover { isHoveringClose = $0 }
            .help("Close")
            .accessibilityLabel("Close Radcap")

            Spacer()
            Text("Radcap")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            // Balance the close button width
            Circle().fill(.clear).frame(width: 12, height: 12)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
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
        .accessibilityHidden(true)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 8) {
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
                .accessibilityLabel(teleprompterScrolling ? "Pause teleprompter" : "Start teleprompter scroll")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Settings")
                .accessibilityLabel("Open Settings")
                .keyboardShortcut(",", modifiers: .command)
            }

            VStack(spacing: 8) {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        cameraPicker
                            .gridColumnAlignment(.leading)
                            .frame(maxWidth: .infinity)
                        microphonePicker
                            .gridColumnAlignment(.leading)
                            .frame(maxWidth: .infinity)
                    }
                    GridRow {
                        Picker("", selection: $captureManager.recordingMode) {
                            ForEach(CaptureManager.RecordingMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .labelsHidden()
                        .gridColumnAlignment(.leading)
                        .frame(maxWidth: .infinity)
                        .help("Recording mode")
                        .accessibilityLabel("Recording Mode")

                        Picker("", selection: $captureManager.cropMode) {
                            ForEach(CaptureManager.CropMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .labelsHidden()
                        .gridColumnAlignment(.leading)
                        .frame(maxWidth: .infinity)
                        .help("Crop mode")
                        .accessibilityLabel("Crop Mode")
                    }
                }
                if captureManager.recordingMode == .audioOnly {
                    Picker("", selection: $captureManager.audioFormat) {
                        ForEach(CaptureManager.AudioFormat.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .help("Audio format")
                    .accessibilityLabel("Audio Format")
                }
            }
        }
        .padding(10)
        .background(reduceTransparency ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor)) : AnyShapeStyle(.regularMaterial))
    }

    private var recordButton: some View {
        Button {
            if captureManager.isRecording {
                coordinator.stopFlow()
            } else {
                coordinator.startFlow()
            }
        } label: {
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
        .disabled(!captureManager.sessionRunning && !captureManager.isRecording)
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
        .accessibilityLabel("Camera")
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
        .accessibilityLabel("Microphone")
    }
}
