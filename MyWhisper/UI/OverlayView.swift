import SwiftUI

enum OverlayMode: Equatable {
    case recording(audioLevel: Float)  // 0.0-1.0 normalized RMS
    case processing
}

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var mode: OverlayMode = .recording(audioLevel: 0)
}

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    private let bubbleSize = CGSize(width: 100, height: 48)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)

            switch viewModel.mode {
            case .recording(let level):
                AudioBarsView(level: level)
            case .processing:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .tint(.blue)
            }
        }
        .frame(width: bubbleSize.width, height: bubbleSize.height)
        .padding(12)
        .frame(width: bubbleSize.width + 24, height: bubbleSize.height + 24)
        .compositingGroup()
    }
}

struct AudioBarsView: View {
    let level: Float

    // 7 bars with stronger emphasis in the center for a cleaner waveform-like look.
    private let barMultipliers: [CGFloat] = [0.32, 0.5, 0.72, 1.0, 0.72, 0.5, 0.32]
    private let minHeight: CGFloat = 6
    private let maxHeight: CGFloat = 26

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.38, blue: 0.48),
                Color(red: 0.93, green: 0.27, blue: 0.59),
                Color(red: 0.56, green: 0.36, blue: 0.96)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(0..<barMultipliers.count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(gradient)
                    .frame(width: 5, height: barHeight(for: index))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
                    }
                    .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.7).opacity(0.18), radius: 3, y: 1)
                    .opacity(barOpacity(for: index))
            }
        }
        .padding(.horizontal, 16)
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.78), value: level)
    }

    /// Computes bar height for the given index based on audio level.
    /// Made internal (not private) to allow unit testing of reactive bar height logic (REC-03).
    func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(max(0, min(1, level)))
        let range = maxHeight - minHeight
        return minHeight + range * normalizedLevel * barMultipliers[index]
    }

    private func barOpacity(for index: Int) -> Double {
        let normalizedLevel = Double(max(0, min(1, level)))
        let emphasis = Double(barMultipliers[index])
        return 0.55 + (normalizedLevel * 0.35) + (emphasis * 0.08)
    }
}
