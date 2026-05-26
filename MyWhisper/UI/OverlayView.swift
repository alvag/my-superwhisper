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
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.10),
                                    Color(red: 0.86, green: 0.33, blue: 0.86).opacity(0.02),
                                    .black.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.14), radius: 9, y: 4)

            switch viewModel.mode {
            case .recording(let level):
                AudioBarsView(level: level)
            case .processing:
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 3)
                        .frame(width: 26, height: 26)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.74)
                        .tint(Color(red: 0.94, green: 0.27, blue: 0.62))
                }
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

    // 15 asymmetric bars create a compact spectral ribbon instead of a mirrored waveform.
    private let barMultipliers: [CGFloat] = [
        0.30, 0.55, 0.40, 0.72, 0.50,
        0.88, 0.64, 1.00, 0.74, 0.48,
        0.82, 0.56, 0.66, 0.36, 0.52
    ]
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 24

    var barCount: Int { barMultipliers.count }

    private var normalizedLevel: CGFloat {
        CGFloat(max(0, min(1, level)))
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.45, blue: 0.36),
                Color(red: 0.98, green: 0.24, blue: 0.56),
                Color(red: 0.58, green: 0.35, blue: 1.0)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    var body: some View {
        ZStack {
            HStack(alignment: .center, spacing: 2.4) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(gradient)
                        .frame(width: 3.6, height: barHeight(for: index))
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.45)
                        }
                        .shadow(
                            color: Color(red: 0.98, green: 0.24, blue: 0.56).opacity(0.04 + Double(normalizedLevel) * 0.20),
                            radius: 2.2,
                            y: 0.6
                        )
                        .opacity(barOpacity(for: index))
                }
            }
        }
        .frame(width: 88, height: 30)
        .animation(.easeInOut(duration: 0.14), value: level)
    }

    /// Computes bar height for the given index based on audio level.
    /// Made internal (not private) to allow unit testing of reactive bar height logic (REC-03).
    func barHeight(for index: Int) -> CGFloat {
        let range = maxHeight - minHeight
        return minHeight + range * normalizedLevel * barMultipliers[index]
    }

    private func barOpacity(for index: Int) -> Double {
        let level = Double(normalizedLevel)
        let emphasis = Double(barMultipliers[index])
        return min(1, 0.34 + (level * 0.48) + (emphasis * 0.12))
    }
}
