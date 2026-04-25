import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let outputDirectoryPath      = "outputDirectoryPath"
        static let teleprompterText         = "teleprompterText"
        static let teleprompterSpeed        = "teleprompterSpeed"
        static let teleprompterFontSize     = "teleprompterFontSize"
        static let windowX                  = "windowX"
        static let windowY                  = "windowY"
        static let recordingPreviewOpacity  = "recordingPreviewOpacity"
    }

    @Published var outputDirectory: URL? {
        didSet { UserDefaults.standard.set(outputDirectory?.path, forKey: Key.outputDirectoryPath) }
    }

    @Published var teleprompterText: String {
        didSet { UserDefaults.standard.set(teleprompterText, forKey: Key.teleprompterText) }
    }

    @Published var teleprompterSpeed: Double {
        didSet { UserDefaults.standard.set(teleprompterSpeed, forKey: Key.teleprompterSpeed) }
    }

    @Published var teleprompterFontSize: Double {
        didSet { UserDefaults.standard.set(teleprompterFontSize, forKey: Key.teleprompterFontSize) }
    }

    @Published var recordingPreviewOpacity: Double {
        didSet { UserDefaults.standard.set(recordingPreviewOpacity, forKey: Key.recordingPreviewOpacity) }
    }

    private init() {
        if let path = UserDefaults.standard.string(forKey: Key.outputDirectoryPath) {
            outputDirectory = URL(fileURLWithPath: path)
        }
        teleprompterText = UserDefaults.standard.string(forKey: Key.teleprompterText) ?? ""
        let speed = UserDefaults.standard.double(forKey: Key.teleprompterSpeed)
        teleprompterSpeed = speed > 0 ? speed : 1.5
        let size = UserDefaults.standard.double(forKey: Key.teleprompterFontSize)
        teleprompterFontSize = size > 0 ? size : 32
        let opacity = UserDefaults.standard.double(forKey: Key.recordingPreviewOpacity)
        recordingPreviewOpacity = opacity > 0 ? opacity : 0.6
    }

    var effectiveOutputDirectory: URL {
        outputDirectory ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }
}
