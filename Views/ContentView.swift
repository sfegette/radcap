import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var captureManager: CaptureManager
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var coordinator: RecordingCoordinator
    @State private var showSettings = false
    @State private var showFormatting = false
    @State private var teleprompterScrolling = false
    @State private var isEditing = false
    @State private var isHoveringClose = false

    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    let onClose: () -> Void

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { captureManager.lastError != nil },
            set: { if !$0 { captureManager.lastError = nil } }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            windowChrome
            previewSection
            Divider()
            TeleprompterView(isScrolling: $teleprompterScrolling, isEditing: $isEditing)
                .frame(maxWidth: .infinity, minHeight: 180)
                .environmentObject(settings)
            Divider()
            controlsSection
        }
        .frame(minWidth: 340, minHeight: 520)
        .background(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.ultraThinMaterial),
                    in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .alert("Recording Error", isPresented: errorAlertBinding, presenting: captureManager.lastError) { _ in
            Button("OK") { captureManager.lastError = nil }
        } message: { message in
            Text(message)
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
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fill)
            .clipped()
            .background(Color.black)

            if captureManager.isRecording {
                recordingBadge
            }
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

                // Prompter controls — grouped visually
                HStack(spacing: 6) {
                    Button {
                        if isEditing { teleprompterScrolling = false }
                        withAnimation(.easeInOut(duration: 0.15)) { isEditing.toggle() }
                    } label: {
                        Image(systemName: isEditing ? "checkmark.circle" : "square.and.pencil")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .help(isEditing ? "Done editing" : "Edit script")
                    .accessibilityLabel(isEditing ? "Done editing script" : "Edit script")

                    Button {
                        showFormatting.toggle()
                    } label: {
                        Image(systemName: "textformat")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .help("Text formatting")
                    .accessibilityLabel("Text formatting options")
                    .popover(isPresented: $showFormatting, arrowEdge: .top) {
                        TeleprompterFormatPopover()
                            .environmentObject(settings)
                    }

                    Button {
                        teleprompterScrolling.toggle()
                    } label: {
                        Image(systemName: teleprompterScrolling ? "pause.circle" : "play.circle")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .help(teleprompterScrolling ? "Pause teleprompter" : "Auto-scroll teleprompter")
                    .accessibilityLabel(teleprompterScrolling ? "Pause teleprompter" : "Start teleprompter scroll")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))

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
            }
        }
        .padding(10)
        .background(
            reduceTransparency ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor)) : AnyShapeStyle(.regularMaterial),
            in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 0)
        )
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
                Image(systemName: captureManager.isRecording ? "stop.circle.fill" : (coordinator.isCountingDown ? "timer" : "record.circle.fill"))
                    .foregroundColor(captureManager.isRecording ? .primary : .red)
                Text(captureManager.isRecording ? "Stop" : (coordinator.isCountingDown ? "Starting…" : "Record"))
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 90)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .keyboardShortcut("r", modifiers: [.command, .option])
        .disabled((!captureManager.sessionRunning && !captureManager.isRecording) || coordinator.isCountingDown)
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

// MARK: - Formatting popover (#13)

struct TeleprompterFormatPopover: View {
    @EnvironmentObject var settings: AppSettings
    @State private var availableFonts: [String] = []

    private var previewText: String {
        let sample = settings.teleprompterText
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? "The quick brown fox jumps over the lazy dog."
        return String(sample.prefix(120))
    }

    private var styledFont: Font {
        let size = min(settings.teleprompterFontSize, 24)
        var f: Font = settings.teleprompterFontName.isEmpty
            ? .system(size: size, weight: settings.teleprompterBold ? .bold : .medium)
            : .custom(settings.teleprompterFontName, size: size)
        if settings.teleprompterBold && !settings.teleprompterFontName.isEmpty { f = f.bold() }
        if settings.teleprompterItalic { f = f.italic() }
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Text Formatting")
                .font(.headline)

            // Live preview — decorative, hidden from VoiceOver
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.black)
                Text(previewText)
                    .font(styledFont)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(settings.teleprompterAlignment == 1 ? .center : .leading)
                    .frame(maxWidth: .infinity,
                           alignment: settings.teleprompterAlignment == 1 ? .center : .leading)
                    .padding(10)
            }
            .frame(height: 80)
            .accessibilityHidden(true)

            Divider()

            // Style toggles + alignment
            HStack(spacing: 12) {
                Toggle(isOn: $settings.teleprompterBold) {
                    Label("Bold", systemImage: "bold")
                }
                .toggleStyle(.button)
                .help("Bold")
                .accessibilityLabel("Bold text")

                Toggle(isOn: $settings.teleprompterItalic) {
                    Label("Italic", systemImage: "italic")
                }
                .toggleStyle(.button)
                .help("Italic")
                .accessibilityLabel("Italic text")

                Divider().frame(height: 22)

                Picker("Alignment", selection: $settings.teleprompterAlignment) {
                    Image(systemName: "text.alignleft").tag(0)
                    Image(systemName: "text.aligncenter").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 80)
                .help("Text alignment")
                .accessibilityLabel("Text alignment")
            }

            // Font family
            LabeledContent("Font") {
                Picker("Font", selection: $settings.teleprompterFontName) {
                    Text("System").tag("")
                    Divider()
                    ForEach(availableFonts, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .help("Font family")
                .accessibilityLabel("Font family")
            }

            // Font size
            LabeledContent("Size") {
                HStack {
                    Slider(value: $settings.teleprompterFontSize, in: 16...72, step: 2)
                        .accessibilityLabel("Font size")
                    Text("\(Int(settings.teleprompterFontSize))pt")
                        .frame(width: 44, alignment: .trailing)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            availableFonts = NSFontManager.shared.availableFontFamilies
                .filter { !$0.hasPrefix(".") }
                .sorted()
        }
    }
}
