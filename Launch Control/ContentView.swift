import SwiftUI

struct ContentView: View {
    @State private var currentScreen = 0

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
                            currentScreen += 1
                        } else if verticalAmount > 0, currentScreen > 0 {
                            currentScreen -= 1
                        }
                    }
            )
        }
      
    }
}

#Preview {
    ContentView()
}
