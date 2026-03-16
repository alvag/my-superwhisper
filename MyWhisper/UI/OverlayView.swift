import SwiftUI

enum OverlayMode: Equatable {
    case recording(audioLevel: Float)  // 0.0-1.0 normalized RMS
    case processing
}

struct OverlayView: View {
    var mode: OverlayMode = .recording(audioLevel: 0)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)

            switch mode {
            case .recording(let level):
                AudioBarsView(level: level)
            case .processing:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .tint(.blue)
            }
        }
        .frame(width: 100, height: 48)
    }
}

struct AudioBarsView: View {
    let level: Float

    // 5 bars with different height multipliers for visual variety
    private let barMultipliers: [CGFloat] = [0.5, 0.8, 1.0, 0.8, 0.5]
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 32

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.red)
                    .frame(width: 4, height: barHeight(for: index))
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeOut(duration: 0.05), value: level)
    }

    /// Computes bar height for the given index based on audio level.
    /// Made internal (not private) to allow unit testing of reactive bar height logic (REC-03).
    func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(max(0, min(1, level)))
        let range = maxHeight - minHeight
        return minHeight + range * normalizedLevel * barMultipliers[index]
    }
}
