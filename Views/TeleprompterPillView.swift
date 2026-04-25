import SwiftUI
import AppKit

// Shared observable used by RecordingHUDController to start/stop scrolling
final class TeleprompterScrollModel: ObservableObject {
    @Published var isScrolling = false
}

// MARK: - AppKit scrolling view

// Bypasses SwiftUI layout entirely. Draws text via NSAttributedString in a
// flipped NSView (origin top-left) so y=0 always means "beginning of script".
// CADisplayLink drives the scroll offset; layer.masksToBounds clips overflow.
final class ScrollingTextNSView: NSView {

    var text: String = "" { didSet { needsDisplay = true } }
    var fontSize: CGFloat = 20
    var pps: CGFloat = 50          // pixels per second

    var scrollOffset: CGFloat = 0
    var scrollTimer: Timer?

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = CGColor.clear
    }
    required init?(coder: NSCoder) { fatalError() }

    // Full start: resets scroll position to top and begins scrolling.
    func startScrolling() {
        scrollOffset = 0
        resumeScrolling()
    }

    // Resume from current position (used when voice resumes after a pause).
    func resumeScrolling() {
        guard scrollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.scrollOffset += self.pps / 60.0
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        scrollTimer = timer
        needsDisplay = true
    }

    // Pause: timer stops but scroll position is preserved.
    func pauseScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    // Full stop: resets position to top.
    func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollOffset = 0
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Clip to view bounds before drawing — belt-and-suspenders on top of
        // layer.masksToBounds, which operates in the CALayer coordinate system.
        NSBezierPath.clip(bounds)

        let displayText = text.isEmpty
            ? "No script — tap Edit in the setup window to add one."
            : text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        NSAttributedString(string: displayText, attributes: attrs)
            .draw(in: NSRect(x: 0,
                             y: -scrollOffset,   // negative = moves text up
                             width: bounds.width,
                             height: 100_000))
    }
}

// MARK: - SwiftUI wrapper

private struct ScrollingTextView: NSViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let pps: CGFloat
    let isRecording: Bool   // HUD is visible; resets position when this goes false→true
    let isSpeaking: Bool    // voice activity gate

    func makeNSView(context: Context) -> ScrollingTextNSView {
        ScrollingTextNSView()
    }

    func updateNSView(_ nsView: ScrollingTextNSView, context: Context) {
        nsView.text = text
        nsView.fontSize = fontSize
        nsView.pps = pps

        if !isRecording {
            // Recording ended — reset to top so next session starts fresh.
            if nsView.scrollTimer != nil || nsView.scrollOffset > 0 {
                nsView.stopScrolling()
            }
        } else if isSpeaking {
            // Voice detected — scroll (or keep scrolling).
            nsView.resumeScrolling()
        } else {
            // Recording active but silence — pause in place.
            nsView.pauseScrolling()
        }
    }
}

// MARK: - Pill view

struct TeleprompterPillView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var captureManager: CaptureManager
    @EnvironmentObject var scrollModel: TeleprompterScrollModel

    private static let textW: CGFloat = 680
    private static let textH: CGFloat = 96

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollingTextView(
                text: settings.teleprompterText,
                fontSize: min(settings.teleprompterFontSize, 26),
                pps: CGFloat(settings.teleprompterSpeed) * 14,
                isRecording: scrollModel.isScrolling,
                isSpeaking: captureManager.isSpeaking
            )
            .frame(width: Self.textW, height: Self.textH)

            recordingBadge
        }
        .frame(width: Self.textW, height: Self.textH)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
        .opacity(0.9)
    }

    private var recordingBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)
            Text(captureManager.durationString)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.trailing, 6)
        .padding(.top, 6)
    }
}
