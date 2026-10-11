import SwiftUI

enum ChartMotion {
    static let spring = Animation.spring(response: 0.78, dampingFraction: 0.86)

    static func scaled(_ value: Double, _ reveal: Double) -> Double {
        value * reveal
    }
}

struct GraphReveal<Token: Equatable, Content: View>: View {
    var token: Token
    @ViewBuilder var content: (Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    var body: some View {
        content(reduceMotion ? 1 : progress)
            .onAppear { play(fromZero: false) }
            .onChange(of: token) { _, _ in play(fromZero: true) }
    }

    private func play(fromZero: Bool) {
        guard !reduceMotion else {
            progress = 1
            return
        }
        if fromZero {
            progress = 0
            DispatchQueue.main.async {
                withAnimation(ChartMotion.spring) { progress = 1 }
            }
        } else {
            withAnimation(ChartMotion.spring) { progress = 1 }
        }
    }
}

struct RangeFill: View {
    var progress: Double
    var tint: Color
    var height: CGFloat = 8

    var body: some View {
        let clamped = min(1, max(0, progress))
        GraphReveal(token: clamped) { reveal in
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.moneyStalkerBorder.opacity(0.85))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.72), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: fillWidth(in: geo.size.width, reveal: reveal, progress: clamped))
                }
            }
            .frame(height: height)
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
        }
    }

    private func fillWidth(in width: CGFloat, reveal: Double, progress: Double) -> CGFloat {
        let ratio = progress * reveal
        guard ratio > 0 else { return 0 }
        return max(8, width * ratio)
    }
}
