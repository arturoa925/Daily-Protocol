//
//  PageScrollView.swift
//  Launch Control
//

import SwiftUI

/// Whether the screen a view belongs to is the one currently on display.
///
/// `ContentView` hides off-screen pages from accessibility directly, but that doesn't
/// reach through a `NavigationStack` — its hosting container sits outside the parent's
/// accessibility scope — so screens that use one read this and hide themselves.
private struct IsActiveScreenKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isActiveScreen: Bool {
        get { self[IsActiveScreenKey.self] }
        set { self[IsActiveScreenKey.self] = newValue }
    }
}

/// Whether a screen's scroll view is sitting at its top or bottom edge.
///
/// Both default to `true` so a screen whose content is shorter than the viewport —
/// or that hasn't reported yet — still pages freely in either direction.
struct ScrollEdges: Equatable {
    var atTop = true
    var atBottom = true
}

/// Carries each screen's scroll edges up to `ContentView`, keyed by page index.
///
/// Keyed because all three screens are instantiated at once inside `ContentView`'s
/// `VStack`; an unkeyed preference would let them overwrite one another.
struct ScrollEdgesKey: PreferenceKey {
    static let defaultValue: [Int: ScrollEdges] = [:]

    static func reduce(value: inout [Int: ScrollEdges], nextValue: () -> [Int: ScrollEdges]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// A scroll view that reports whether it's at its top/bottom edge, so the pager in
/// `ContentView` can hand a swipe over to the next screen only once the content
/// inside has been scrolled to its end.
struct PageScrollView<Content: View>: View {
    let page: Int
    @ViewBuilder var content: Content

    @State private var edges = ScrollEdges()

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
        }
        .onScrollGeometryChange(for: ScrollEdges.self) { geometry in
            // 1pt of tolerance keeps rubber-banding and fractional offsets from
            // flickering the edge state.
            ScrollEdges(
                atTop: geometry.contentOffset.y <= geometry.contentInsets.top + 1,
                atBottom: geometry.contentOffset.y + geometry.containerSize.height
                    >= geometry.contentSize.height - 1
            )
        } action: { _, newValue in
            edges = newValue
        }
        .preference(key: ScrollEdgesKey.self, value: [page: edges])
    }
}
