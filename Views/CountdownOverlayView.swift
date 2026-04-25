import SwiftUI

struct CountdownOverlayView: View {
    let startCount: Int
    let onComplete: () -> Void

    @State private var current: Int
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var isDone = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(startCount: Int, onComplete: @escaping () -> Void) {
        self.startCount = startCount
        self.onComplete = onComplete
        _current = State(initialValue: startCount)
    }

    var body: some View {
        ZStack {
            // Near-invisible fill so the NSWindow covers the screen bounds
            Color.black.opacity(0.001)

            Text(isDone ? "●" : "\(current)")
                .font(.system(size: 180, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 6)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onAppear { animateIn() }
        .onReceive(ticker) { _ in
            guard !isDone else { return }
            tick()
        }
    }

    private func animateIn() {
        scale = 1.4
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { scale = 1.0 }
    }

    private func tick() {
        // Animate out current number
        withAnimation(.easeOut(duration: 0.22)) {
            opacity = 0
            scale = 0.65
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if current > 1 {
                current -= 1
                scale = 1.4
                opacity = 1.0
                withAnimation(.spring(duration: 0.38, bounce: 0.35)) { scale = 1.0 }
            } else {
                // Show record dot briefly, then complete
                isDone = true
                scale = 1.4
                opacity = 1.0
                withAnimation(.spring(duration: 0.38, bounce: 0.35)) { scale = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation(.easeOut(duration: 0.2)) { opacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onComplete() }
                }
            }
        }
    }
}
