
import SwiftUI

/// A single bar in the weekly and monthly completion charts: an outlined track showing
/// the day's (or week's) total, with the completed portion filled inside it.
struct CompletionBar: View {
    let barWidth: CGFloat
    let maxBarHeight: CGFloat
    let totalHeight: CGFloat
    let completedHeight: CGFloat
    let isSelected: Bool

    private let cornerRadius: CGFloat = 6

    private let fillGradient = LinearGradient(
        colors: [
            Color.chartBarBottom,
            Color.chartBarTop
        ],
        startPoint: .bottom,
        endPoint: .top
    )

    /// Rounds only the top corners, clamping the radius on short bars so they don't
    /// round into a lozenge.
    private func shape(for height: CGFloat) -> UnevenRoundedRectangle {
        let radius = min(cornerRadius, max(height / 2, 0))

        return UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: radius,
            style: .continuous
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            shape(for: totalHeight)
                .stroke(Color.textPrimary.opacity(0.10), lineWidth: 1)
                .frame(width: barWidth, height: totalHeight)

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(fillGradient)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.13),
                                Color.white.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: max(completedHeight * 0.22, 0))
                    .blur(radius: 2)
                    .allowsHitTesting(false)
            }
            .frame(width: barWidth, height: completedHeight, alignment: .bottom)
            // Clips to the rounded shape rather than the bounding rectangle, so the
            // gloss doesn't bleed past the rounded top corners.
            .clipShape(shape(for: completedHeight))
            .opacity(isSelected ? 1.0 : 0.94)
        }
        .frame(width: barWidth, height: maxBarHeight, alignment: .bottom)
        .offset(y: isSelected ? -3 : 0)
        .shadow(color: isSelected ? .black.opacity(0.18) : .clear, radius: 6, x: 0, y: 3)
    }
}
#Preview("Completion Bars") {
    HStack(alignment: .bottom, spacing: 12) {
        // Empty bar
        CompletionBar(
            barWidth: 30,
            maxBarHeight: 120,
            totalHeight: 80,
            completedHeight: 0,
            isSelected: false
        )
        
        // Partially filled
        CompletionBar(
            barWidth: 30,
            maxBarHeight: 120,
            totalHeight: 100,
            completedHeight: 35,
            isSelected: false
        )
        
        // Half filled
        CompletionBar(
            barWidth: 30,
            maxBarHeight: 120,
            totalHeight: 90,
            completedHeight: 45,
            isSelected: false
        )
        
        // Mostly filled - selected
        CompletionBar(
            barWidth: 30,
            maxBarHeight: 120,
            totalHeight: 110,
            completedHeight: 95,
            isSelected: true
        )
        
        // Fully filled
        CompletionBar(
            barWidth: 30,
            maxBarHeight: 120,
            totalHeight: 120,
            completedHeight: 120,
            isSelected: false
        )
        
        // Very short bar
        CompletionBar(
            barWidth: 30,
            maxBarHeight: 120,
            totalHeight: 20,
            completedHeight: 15,
            isSelected: false
        )
    }
    .padding()
    .background(Color(white: 0.95))
}

