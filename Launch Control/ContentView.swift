import SwiftUI

struct ContentView: View {
    @State private var currentScreen = 0
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false
    @State private var chevronOpacity: Double = 0.15
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ProtocolView()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                CalendarView()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                CompletionContainerView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .offset(y: -CGFloat(currentScreen) * geometry.size.height)
            .animation(.easeInOut(duration: 0.3), value: currentScreen)
            .simultaneousGesture(
                DragGesture()
                    .onEnded { value in
                        let verticalAmount = value.translation.height
                        let horizontalAmount = abs(value.translation.width)

                        guard abs(verticalAmount) > 80, abs(verticalAmount) > horizontalAmount else { return }

                        if verticalAmount < 0, currentScreen < 2 {
                            hasSeenSwipeHint = true
                            currentScreen += 1
                        } else if verticalAmount > 0, currentScreen > 0 {
                            currentScreen -= 1
                        }
                    }
            )
            .accessibilityScrollAction { edge in
                switch edge {
                case .bottom:
                    if currentScreen < 2 {
                        currentScreen += 1
                        hasSeenSwipeHint = true
                    }
                case .top:
                    if currentScreen > 0 {
                        currentScreen -= 1
                    }
                default:
                    break
                }
            }
        }
        .overlay(alignment: .bottom) {
            if currentScreen == 0, !hasSeenSwipeHint {
                Image(systemName: "chevron.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .opacity(chevronOpacity)
                    .padding(.bottom, 40)
                    .accessibilityHidden(true)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                            chevronOpacity = 0.45
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
