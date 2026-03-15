import SwiftUI

// Phase 1: Animated placeholder — three bars pulsing at different rates.
// Phase 2 upgrades to live audio level bars once AudioRecorder provides meter data.
struct OverlayView: View {
    @State private var animating = false

    var body: some View {
        ZStack {
            // Background capsule
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(width: 4)
                        .frame(height: animating ? barHeight(index: index, phase: 1.0) : 8)
                        .animation(
                            .easeInOut(duration: 0.4 + Double(index) * 0.08)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.06),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(width: 100, height: 48)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }

    private func barHeight(index: Int, phase: Double) -> CGFloat {
        let heights: [CGFloat] = [12, 24, 36, 24, 12]
        return heights[index % heights.count]
    }
}
