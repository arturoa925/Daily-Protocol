
import SwiftUI
// CGFloat is a double used specifically for UI math
struct NotesIndicator: View {
    var size: CGFloat = 4
    var spacing: CGFloat = 4
    var tint: Color = .white
    var animated: Bool = true

    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: spacing) {
            Circle()
                .frame(width: size, height: size)
                .opacity(opacity(for: 0))
            Circle()
                .frame(width: size, height: size)
                .opacity(opacity(for: 1))
            Circle()
                .frame(width: size, height: size)
                .opacity(opacity(for: 2))
        }
        .foregroundStyle(tint)
        .accessibilityLabel("More content available")
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        guard animated else { return 1.0 }
        // Stagger the dots using phase offset
        let base = 0.3
        let maxOpacity = 1.0
        let delay = 0.2 * Double(index)
        let value = sin((phase - delay) * .pi)
        let normalized = max(base, min(maxOpacity, (value + 1) / 2))
        return normalized
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 8) {
            Text("This is a note")
                .font(.body)
                .foregroundColor(.white)
            NotesIndicator(size: 5, spacing: 5, tint: .white.opacity(0.6))
        }
        .padding()
        .background(Color.black)

        HStack(spacing: 8) {
            Text("More text with indicator")
            NotesIndicator(size: 4, spacing: 4, tint: .secondary, animated: false)
        }
        .padding()
    }
}

