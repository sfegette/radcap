import SwiftUI

struct TeleprompterView: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var isScrolling: Bool
    @Binding var isEditing: Bool

    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?

    var body: some View {
        ZStack {
            Color(NSColor.textBackgroundColor).opacity(0.85)

            if isEditing {
                editingView
            } else if isScrolling {
                autoScrollView
            } else {
                manualScrollView
            }
        }
        .onChange(of: isScrolling) { _, scrolling in
            if scrolling {
                scrollOffset = 0
                startScrollTimer()
            } else {
                stopScrollTimer()
            }
        }
        .onDisappear { stopScrollTimer() }
    }

    // MARK: - Subviews

    private var editingView: some View {
        TextEditor(text: $settings.teleprompterText)
            .font(styledFont)
            .scrollContentBackground(.hidden)
            .padding()
    }

    private var manualScrollView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            scriptText
        }
    }

    private var autoScrollView: some View {
        GeometryReader { proxy in
            Text(settings.teleprompterText.isEmpty ? "Tap Edit to add your script…" : settings.teleprompterText)
                .font(styledFont)
                .foregroundColor(settings.teleprompterText.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .padding(.bottom, 200)
                .frame(width: proxy.size.width, alignment: frameAlignment)
                .offset(y: -scrollOffset)
        }
        .clipped()
    }

    private var scriptText: some View {
        Text(settings.teleprompterText.isEmpty ? "Tap Edit to add your script…" : settings.teleprompterText)
            .font(styledFont)
            .foregroundColor(settings.teleprompterText.isEmpty ? .secondary : .primary)
            .multilineTextAlignment(textAlignment)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding()
            .padding(.bottom, 200)
    }

    // MARK: - Style helpers

    private var styledFont: Font {
        var f = Font.system(size: settings.teleprompterFontSize,
                            weight: settings.teleprompterBold ? .bold : .medium)
        if settings.teleprompterItalic { f = f.italic() }
        return f
    }

    private var textAlignment: TextAlignment {
        settings.teleprompterAlignment == 1 ? .center : .leading
    }

    private var frameAlignment: Alignment {
        settings.teleprompterAlignment == 1 ? .center : .topLeading
    }

    // MARK: - Auto-scroll

    private func startScrollTimer() {
        let pps: CGFloat = CGFloat(settings.teleprompterSpeed) * 50.0
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            scrollOffset += pps / 60.0
        }
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
}
