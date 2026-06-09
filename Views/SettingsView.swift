import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            Form {
                Section("Output") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Save recordings to")
                            Text(settings.effectiveOutputDirectory.abbreviatingWithTildeInPath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Choose…") { chooseFolder() }
                            .buttonStyle(.borderless)
                    }
                    if settings.outputDirectory != nil {
                        Button(AppSettings.isSandboxed ? "Reset to Movies" : "Reset to Desktop") {
                            settings.outputDirectory = nil
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    }
                    LabeledContent("Video Format") {
                        Picker("", selection: $settings.videoFormat) {
                            ForEach(AppSettings.VideoFormat.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .labelsHidden()
                        .help("Container format for video recordings (MOV and MP4 both use H.264)")
                        .accessibilityLabel("Video Format")
                    }
                    LabeledContent("Audio Format") {
                        Picker("", selection: $settings.audioFormat) {
                            ForEach(AppSettings.AudioFormat.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .labelsHidden()
                        .help("Audio format used when recording in Audio Only mode")
                        .accessibilityLabel("Audio Format")
                    }
                }

                Section("Recording") {
                    LabeledContent("Preview Opacity") {
                        HStack {
                            Slider(value: $settings.recordingPreviewOpacity, in: 0.15...1.0, step: 0.05)
                            EditableValueLabel(
                                value: $settings.recordingPreviewOpacity,
                                range: 0.15...1.0,
                                label: "Preview Opacity",
                                display: { "\(Int($0 * 100))%" },
                                parse: { s in
                                    let n = s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                                    return Double(n).map { $0 / 100 }
                                }
                            )
                        }
                    }
                }

                Section("Teleprompter") {
                    LabeledContent("Font Size") {
                        HStack {
                            Slider(value: $settings.teleprompterFontSize, in: 16...72, step: 2)
                            EditableValueLabel(
                                value: $settings.teleprompterFontSize,
                                range: 16...72,
                                label: "Font Size",
                                display: { "\(Int($0))pt" },
                                parse: { Double($0.replacingOccurrences(of: "pt", with: "")) }
                            )
                        }
                    }

                    LabeledContent("Scroll Speed") {
                        HStack {
                            Slider(value: speedSliderBinding, in: 0...1)
                                .accessibilityValue(String(format: "%.2fx", settings.teleprompterSpeed))
                            EditableValueLabel(
                                value: $settings.teleprompterSpeed,
                                range: 0.25...2.0,
                                label: "Scroll Speed",
                                display: { String(format: "%.2fx", $0) },
                                parse: { Double($0.replacingOccurrences(of: "x", with: "")) }
                            )
                        }
                    }

                    LabeledContent("Pre-scroll Pause") {
                        HStack {
                            Slider(value: $settings.teleprompterPreScrollDelay, in: 0...5, step: 0.5)
                            EditableValueLabel(
                                value: $settings.teleprompterPreScrollDelay,
                                range: 0...5,
                                label: "Pre-scroll Pause",
                                display: { $0 == 0 ? "0s" : String(format: "%.1fs", $0) },
                                parse: { Double($0.replacingOccurrences(of: "s", with: "")) }
                            )
                        }
                    }

                    LabeledContent("Prompter Lines") {
                        HStack {
                            Slider(value: linesSliderBinding, in: 2...10, step: 1)
                            EditableValueLabel(
                                value: linesSliderBinding,
                                range: 2...10,
                                label: "Prompter Lines",
                                display: { "\(Int($0))" },
                                parse: { Double($0.trimmingCharacters(in: .whitespaces)) }
                            )
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version") {
                        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                        Text("\(v) (\(b))")
                            .monospacedDigit()
                    }
                    LabeledContent("Bundle ID", value: "com.sfegette.radcap")
                    Link("Visit the Radcap Website", destination: URL(string: "https://brilliantmindworks.com/#/apps/radcap/")!)
                        .foregroundStyle(.blue)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 380, height: 520)
    }

    // MARK: - Piecewise speed binding: 0.25→1.0 in left half, 1.0→2.0 in right half.
    // This puts 1.0 at the exact physical center of the slider.
    private var speedSliderBinding: Binding<Double> {
        Binding(
            get: {
                let s = settings.teleprompterSpeed
                if s <= 1.0 {
                    return (s - 0.25) / 0.75 * 0.5
                } else {
                    return 0.5 + (s - 1.0) / 1.0 * 0.5
                }
            },
            set: { t in
                if t <= 0.5 {
                    settings.teleprompterSpeed = 0.25 + t * 1.5
                } else {
                    settings.teleprompterSpeed = 1.0 + (t - 0.5) * 2.0
                }
            }
        )
    }

    private var linesSliderBinding: Binding<Double> {
        Binding(
            get: { Double(settings.teleprompterVisibleLines) },
            set: { settings.teleprompterVisibleLines = Int($0.rounded()) }
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose where Radcap saves recordings"
        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url
        }
    }
}

// MARK: - Editable value label

// Inline TextField next to a slider. Shows formatted value at rest; accepts raw
// number input (with or without units) on click, clamps on commit/blur.
private struct EditableValueLabel: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var label: String = ""
    let display: (Double) -> String
    let parse: (String) -> Double?

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .frame(width: 52)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .focused($focused)
            .onSubmit { commit() }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .onChange(of: value) { _, _ in
                if !focused { text = display(value) }
            }
            .onAppear { text = display(value) }
            .accessibilityLabel(label.isEmpty ? "Value" : label)
    }

    private func commit() {
        if let raw = parse(text) {
            value = min(max(raw, range.lowerBound), range.upperBound)
        }
        text = display(value)
    }
}

// MARK: -

private extension URL {
    var abbreviatingWithTildeInPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}

