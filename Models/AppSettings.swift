import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let outputDirectoryPath          = "outputDirectoryPath"
        static let teleprompterText             = "teleprompterText"
        static let teleprompterSpeed            = "teleprompterSpeed"
        static let teleprompterFontSize         = "teleprompterFontSize"
        static let teleprompterPreScrollDelay   = "teleprompterPreScrollDelay"
        static let teleprompterVisibleLines     = "teleprompterVisibleLines"
        static let teleprompterBold             = "teleprompterBold"
        static let teleprompterItalic           = "teleprompterItalic"
        static let teleprompterAlignment        = "teleprompterAlignment"  // 0=leading 1=center
        static let windowX                      = "windowX"
        static let windowY                      = "windowY"
        static let recordingPreviewOpacity      = "recordingPreviewOpacity"
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

    @Published var teleprompterPreScrollDelay: Double {
        didSet { UserDefaults.standard.set(teleprompterPreScrollDelay, forKey: Key.teleprompterPreScrollDelay) }
    }

    @Published var teleprompterVisibleLines: Int {
        didSet { UserDefaults.standard.set(teleprompterVisibleLines, forKey: Key.teleprompterVisibleLines) }
    }

    @Published var teleprompterBold: Bool {
        didSet { UserDefaults.standard.set(teleprompterBold, forKey: Key.teleprompterBold) }
    }

    @Published var teleprompterItalic: Bool {
        didSet { UserDefaults.standard.set(teleprompterItalic, forKey: Key.teleprompterItalic) }
    }

    @Published var teleprompterAlignment: Int {
        didSet { UserDefaults.standard.set(teleprompterAlignment, forKey: Key.teleprompterAlignment) }
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
        teleprompterSpeed = speed > 0 ? min(max(speed, 0.25), 2.0) : 0.7
        let size = UserDefaults.standard.double(forKey: Key.teleprompterFontSize)
        teleprompterFontSize = size > 0 ? size : 32
        teleprompterPreScrollDelay = max(0, UserDefaults.standard.double(forKey: Key.teleprompterPreScrollDelay))
        let lines = UserDefaults.standard.integer(forKey: Key.teleprompterVisibleLines)
        teleprompterVisibleLines = lines >= 2 ? min(lines, 10) : 5
        teleprompterBold = UserDefaults.standard.bool(forKey: Key.teleprompterBold)
        teleprompterItalic = UserDefaults.standard.bool(forKey: Key.teleprompterItalic)
        teleprompterAlignment = UserDefaults.standard.integer(forKey: Key.teleprompterAlignment)
        let opacity = UserDefaults.standard.double(forKey: Key.recordingPreviewOpacity)
        recordingPreviewOpacity = opacity > 0 ? opacity : 0.6
    }

    var effectiveOutputDirectory: URL {
        outputDirectory ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }
}
