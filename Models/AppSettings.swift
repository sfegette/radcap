import Foundation
import AVFoundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum AudioFormat: String, CaseIterable, Identifiable {
        case m4a = "M4A (AAC)"
        case wav = "WAV (Lossless)"
        var id: String { rawValue }
        var fileExtension: String { self == .m4a ? "m4a" : "wav" }
        var avFileType: AVFileType  { self == .m4a ? .m4a  : .wav  }
    }

    enum VideoFormat: String, CaseIterable, Identifiable {
        case mov = "MOV"
        case mp4 = "MP4"
        var id: String { rawValue }
        var fileExtension: String { self == .mov ? "mov" : "mp4" }
        var avFileType: AVFileType  { self == .mov ? .mov  : .mp4  }
    }

    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    private enum Key {
        static let outputDirectoryPath          = "outputDirectoryPath"
        static let outputDirectoryBookmark      = "outputDirectoryBookmark"
        static let audioFormat                  = "audioFormat"
        static let videoFormat                  = "videoFormat"
        static let teleprompterText             = "teleprompterText"
        static let teleprompterSpeed            = "teleprompterSpeed"
        static let teleprompterFontSize         = "teleprompterFontSize"
        static let teleprompterPreScrollDelay   = "teleprompterPreScrollDelay"
        static let teleprompterVisibleLines     = "teleprompterVisibleLines"
        static let teleprompterBold             = "teleprompterBold"
        static let teleprompterItalic           = "teleprompterItalic"
        static let teleprompterAlignment        = "teleprompterAlignment"  // 0=leading 1=center
        static let teleprompterFontName         = "teleprompterFontName"   // "" = system font
        static let windowX                      = "windowX"
        static let windowY                      = "windowY"
        static let recordingPreviewOpacity      = "recordingPreviewOpacity"
    }

    private var securityScopedURL: URL?

    @Published var outputDirectory: URL? {
        didSet {
            securityScopedURL?.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
            guard let url = outputDirectory else {
                UserDefaults.standard.removeObject(forKey: Key.outputDirectoryPath)
                UserDefaults.standard.removeObject(forKey: Key.outputDirectoryBookmark)
                return
            }
            UserDefaults.standard.set(url.path, forKey: Key.outputDirectoryPath)
            if AppSettings.isSandboxed,
               let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: Key.outputDirectoryBookmark)
                if url.startAccessingSecurityScopedResource() { securityScopedURL = url }
            }
        }
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
    @Published var teleprompterFontName: String {
        didSet { UserDefaults.standard.set(teleprompterFontName, forKey: Key.teleprompterFontName) }
    }
    @Published var recordingPreviewOpacity: Double {
        didSet { UserDefaults.standard.set(recordingPreviewOpacity, forKey: Key.recordingPreviewOpacity) }
    }
    @Published var audioFormat: AudioFormat {
        didSet { UserDefaults.standard.set(audioFormat.rawValue, forKey: Key.audioFormat) }
    }
    @Published var videoFormat: VideoFormat {
        didSet { UserDefaults.standard.set(videoFormat.rawValue, forKey: Key.videoFormat) }
    }

    private init() {
        if AppSettings.isSandboxed,
           let bookmarkData = UserDefaults.standard.data(forKey: Key.outputDirectoryBookmark) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) {
                outputDirectory = url
                if url.startAccessingSecurityScopedResource() { securityScopedURL = url }
                if isStale,
                   let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    UserDefaults.standard.set(fresh, forKey: Key.outputDirectoryBookmark)
                }
            }
        } else if let path = UserDefaults.standard.string(forKey: Key.outputDirectoryPath) {
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
        // Default to center (1); use stored value only if key has been explicitly set
        teleprompterAlignment = UserDefaults.standard.object(forKey: Key.teleprompterAlignment) != nil
            ? UserDefaults.standard.integer(forKey: Key.teleprompterAlignment) : 1
        teleprompterFontName = UserDefaults.standard.string(forKey: Key.teleprompterFontName) ?? ""
        let opacity = UserDefaults.standard.double(forKey: Key.recordingPreviewOpacity)
        recordingPreviewOpacity = opacity > 0 ? opacity : 0.6
        let fmtRaw = UserDefaults.standard.string(forKey: Key.audioFormat) ?? ""
        audioFormat = AudioFormat(rawValue: fmtRaw) ?? .m4a
        let vfmtRaw = UserDefaults.standard.string(forKey: Key.videoFormat) ?? ""
        videoFormat = VideoFormat(rawValue: vfmtRaw) ?? .mov
    }

    var effectiveOutputDirectory: URL {
        if let dir = outputDirectory { return dir }
        let fallbackSearch: FileManager.SearchPathDirectory = AppSettings.isSandboxed ? .moviesDirectory : .desktopDirectory
        return FileManager.default.urls(for: fallbackSearch, in: .userDomainMask)[0]
    }
}
