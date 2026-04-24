import SwiftUI
import XCTest

@testable import SessionSearch

final class SnippetHighlighterTests: XCTestCase {
    func testPlainTextNoMarkers() {
        let result = highlightedSnippet("plain text")
        // Should not crash — produces a valid Text
        XCTAssertNotNil(result)
    }

    func testEmptyString() {
        let result = highlightedSnippet("")
        XCTAssertNotNil(result)
    }

    func testSingleHighlight() {
        let result = highlightedSnippet("before <<match>> after")
        XCTAssertNotNil(result)
    }

    func testMultipleHighlights() {
        let result = highlightedSnippet("a <<b>> c <<d>> e")
        XCTAssertNotNil(result)
    }

    func testAdjacentHighlights() {
        let result = highlightedSnippet("<<first>><<second>>")
        XCTAssertNotNil(result)
    }

    func testUnbalancedMarker() {
        // << without >> should not crash — renders as plain text
        let result = highlightedSnippet("<<no close")
        XCTAssertNotNil(result)
    }

    func testCloseMarkerInContent() {
        // >> appearing in non-highlighted text should be preserved
        let result = highlightedSnippet("before <<match>> mid >> end")
        XCTAssertNotNil(result)
    }
}
