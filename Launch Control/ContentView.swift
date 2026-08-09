import SwiftUI

struct ContentView: View {
    @State private var currentScreen = 0
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false
    @State private var chevronOpacity: Double = 0.15
    @State private var pageEdges: [Int: ScrollEdges] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            // Each screen is offset individually rather than sliding one tall stack,
            // so the visible screen always sits at offset 0 and reports accessibility
            // frames that match where it actually appears.
            //
            // Deliberately not clipped: each screen already fills exactly one
            // device-screen's worth of space and is offset in whole-screen
            // increments, so an inactive screen never overlaps the visible one at
            // rest. Clipping this container also clips every screen's own
            // Color.appBackground.ignoresSafeArea() background, cutting it off at
            // the safe area instead of the true device edges — and expanding the
            // clip boundary back out (via .ignoresSafeArea() on the ZStack) makes
            // the ZStack larger than its children, which then center inside it and
            // leave gaps at the top and bottom instead.
            ZStack {
                screen(0, in: geometry) { ProtocolView() }
                screen(1, in: geometry) { CalendarView() }
                screen(2, in: geometry) { CompletionContainerView() }
            }
            .animation(.easeInOut(duration: 0.3), value: currentScreen)
            .simultaneousGesture(
                DragGesture()
                    .onEnded { value in
                        let verticalAmount = value.translation.height
                        let horizontalAmount = abs(value.translation.width)

                        guard abs(verticalAmount) > 80, abs(verticalAmount) > horizontalAmount else { return }

                        // Hand the swipe to the pager only once the content inside this
                        // screen has been scrolled to the end it's heading towards.
                        let edges = pageEdges[currentScreen]

                        if verticalAmount < 0, currentScreen < 2, edges?.atBottom != false {
                            hasSeenSwipeHint = true
                            currentScreen += 1
                        } else if verticalAmount > 0, currentScreen > 0, edges?.atTop != false {
                            currentScreen -= 1
                        }
                    }
            )
            .onPreferenceChange(ScrollEdgesKey.self) { newValue in
                pageEdges = newValue
            }
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

    @ViewBuilder
    private func screen<Content: View>(
        _ index: Int,
        in geometry: GeometryProxy,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .offset(y: CGFloat(index - currentScreen) * geometry.size.height)
            // Off-screen pages have to leave the accessibility tree, or VoiceOver
            // walks straight into content the user can't see.
            .accessibilityHidden(currentScreen != index)
            // A NavigationStack hosts its content outside this view's accessibility
            // scope, so screens that use one hide themselves off this instead.
            .environment(\.isActiveScreen, currentScreen == index)
            // Stops a mis-tap landing on a neighbouring page mid-animation.
            .allowsHitTesting(currentScreen == index)
    }
}

#Preview {
    ContentView()
}
