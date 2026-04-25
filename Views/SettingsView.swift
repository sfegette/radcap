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
                        Button("Reset to Desktop") {
                            settings.outputDirectory = nil
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    }
                }

                Section("Teleprompter") {
                    LabeledContent("Font Size") {
                        HStack {
                            Slider(value: $settings.teleprompterFontSize, in: 16...72, step: 2)
                            Text("\(Int(settings.teleprompterFontSize))pt")
                                .frame(width: 44, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("Scroll Speed") {
                        HStack {
                            Slider(value: $settings.teleprompterSpeed, in: 0.5...5.0, step: 0.5)
                            Text(String(format: "%.1fx", settings.teleprompterSpeed))
                                .frame(width: 44, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Bundle ID", value: "com.sfegette.madcap")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 380, height: 400)
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

// MARK: -

private extension URL {
    var abbreviatingWithTildeInPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
