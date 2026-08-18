//
//  ScrollEdgesTests.swift
//  Launch ControlTests
//

import Testing
@testable import Launch_Control

struct ScrollEdgesTests {

    @Test func defaultScrollEdgesAreBothTrue() {
        let edges = ScrollEdges()
        #expect(edges.atTop == true)
        #expect(edges.atBottom == true)
    }

    @Test func preferenceKeyDefaultValueIsEmpty() {
        #expect(ScrollEdgesKey.defaultValue.isEmpty)
    }

    @Test func reduceMergesEntriesFromDifferentPages() {
        var value: [Int: ScrollEdges] = [0: ScrollEdges(atTop: true, atBottom: false)]
        ScrollEdgesKey.reduce(value: &value) { [1: ScrollEdges(atTop: false, atBottom: true)] }

        #expect(value.count == 2)
        #expect(value[0] == ScrollEdges(atTop: true, atBottom: false))
        #expect(value[1] == ScrollEdges(atTop: false, atBottom: true))
    }

    @Test func reduceLetsTheNewerValueWinForTheSamePage() {
        var value: [Int: ScrollEdges] = [0: ScrollEdges(atTop: true, atBottom: true)]
        ScrollEdgesKey.reduce(value: &value) { [0: ScrollEdges(atTop: false, atBottom: false)] }

        #expect(value.count == 1)
        #expect(value[0] == ScrollEdges(atTop: false, atBottom: false))
    }
}
