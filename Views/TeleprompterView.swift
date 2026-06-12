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
            } else if settings.teleprompterText.isEmpty {
                emptyStateView
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

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.fill.secondary, in: RoundedRectangle(cornerRadius: 8))
                Image(systemName: "textformat")
                    .font(.system(size: 22))
                    .foregroundStyle(.quaternary)
                Image(systemName: "play.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))

            Text("Click the edit icon to paste\nor type your script")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
            Text(settings.teleprompterText)
                .font(styledFont)
                .foregroundColor(.primary)
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
        Text(settings.teleprompterText)
            .font(styledFont)
            .foregroundColor(.primary)
            .multilineTextAlignment(textAlignment)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding()
            .padding(.bottom, 200)
    }

    // MARK: - Style helpers

    private var styledFont: Font {
        var f: Font = settings.teleprompterFontName.isEmpty
            ? .system(size: settings.teleprompterFontSize, weight: settings.teleprompterBold ? .bold : .medium)
            : .custom(settings.teleprompterFontName, size: settings.teleprompterFontSize)
        if settings.teleprompterBold && !settings.teleprompterFontName.isEmpty { f = f.bold() }
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
