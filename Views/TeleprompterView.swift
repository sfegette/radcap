import SwiftUI

struct TeleprompterView: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var isScrolling: Bool

    @State private var isEditing = false
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(NSColor.textBackgroundColor).opacity(0.85)

            if isEditing {
                editingView
            } else if isScrolling {
                autoScrollView
            } else {
                manualScrollView
            }

            editToggleButton
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
            .font(.system(size: settings.teleprompterFontSize))
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
                .font(.system(size: settings.teleprompterFontSize, weight: .medium))
                .foregroundColor(settings.teleprompterText.isEmpty ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .padding(.bottom, 200)
                .frame(width: proxy.size.width, alignment: .topLeading)
                .offset(y: -scrollOffset)
        }
        .clipped()
    }

    private var scriptText: some View {
        Text(settings.teleprompterText.isEmpty ? "Tap Edit to add your script…" : settings.teleprompterText)
            .font(.system(size: settings.teleprompterFontSize, weight: .medium))
            .foregroundColor(settings.teleprompterText.isEmpty ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.bottom, 200) // trail-off space
    }

    private var editToggleButton: some View {
        Button(isEditing ? "Done" : "Edit") {
            if isEditing { isScrolling = false }
            withAnimation(.easeInOut(duration: 0.15)) { isEditing.toggle() }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)
        .padding(6)
    }

    // MARK: - Auto-scroll

    private func startScrollTimer() {
        // pixels-per-second = speed factor × 50
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
