import SwiftUI
#if os(macOS)
import AppKit
#endif
import ComposableArchitecture
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct MarkdownDetailViewTests {
    private func assertSnapshots<V: View>(
        _ view: V,
        name: String,
        record: Bool = false,
        file: StaticString = #filePath,
        testName: String = #function
    ) {
        let shouldRecord = record || ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = measuredFittingSize(for: view, width: 500)
        let failure = verifySnapshot(
            of: hosting,
            as: .imageHiDPI(size: size),
            named: name,
            record: shouldRecord,
            file: file,
            testName: testName
        )
        #expect(failure == nil)
#elseif os(iOS) || os(tvOS)
        let lightFailure = verifySnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .light)),
            named: "\(name).light",
            record: shouldRecord,
            file: file,
            testName: testName
        )
        #expect(lightFailure == nil)
        let darkFailure = verifySnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .dark)),
            named: "\(name).dark",
            record: shouldRecord,
            file: file,
            testName: testName
        )
        #expect(darkFailure == nil)
#endif
    }

    @Test
    func markdownDetailViewRenderedAttributedContent() {
        let view = NavigationStack {
            MarkdownDetailView(
                store: Store(
                    initialState: MarkdownDetailFeature.State(
                        markdown: "## Header\n\n- one\n- two",
                        attributedString: AttributedString("Header\n• one\n• two")
                    )
                ) {
                    MarkdownDetailFeature()
                }
            )
        }
#if os(macOS)
        .frame(width: 500, height: 800)
#elseif os(iOS) || os(tvOS)
        .frame(width: 390, height: 844)
#endif

        assertSnapshots(view, name: "renderedAttributedContent")
    }

    @Test
    func markdownDetailViewFallsBackToRawMarkdownText() {
        let view = NavigationStack {
            MarkdownDetailView(
                store: Store(
                    initialState: MarkdownDetailFeature.State(
                        markdown: "## Header\n\n- one\n- two",
                        attributedString: AttributedString()
                    )
                ) {
                    MarkdownDetailFeature()
                }
            )
        }
#if os(macOS)
        .frame(width: 500, height: 800)
#elseif os(iOS) || os(tvOS)
        .frame(width: 390, height: 844)
#endif

        assertSnapshots(view, name: "rawMarkdownFallback")
    }
}
