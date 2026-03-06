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
struct PodcastTranscriptDetailViewTests {
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
        if shouldRecord {
            _ = verifySnapshot(
                of: hosting,
                as: .imageHiDPI(size: size),
                named: name,
                record: true,
                file: file,
                testName: testName
            )
            return
        }
        let failure = verifySnapshot(
            of: hosting,
            as: .imageHiDPI(size: size),
            named: name,
            record: false,
            file: file,
            testName: testName
        )
        #expect(failure == nil)
#elseif os(iOS) || os(tvOS)
        if shouldRecord {
            _ = verifySnapshot(
                of: view,
                as: .image(traits: .init(userInterfaceStyle: .light)),
                named: "\(name).light",
                record: true,
                file: file,
                testName: testName
            )
            _ = verifySnapshot(
                of: view,
                as: .image(traits: .init(userInterfaceStyle: .dark)),
                named: "\(name).dark",
                record: true,
                file: file,
                testName: testName
            )
            return
        }
        let lightFailure = verifySnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .light)),
            named: "\(name).light",
            record: false,
            file: file,
            testName: testName
        )
        #expect(lightFailure == nil)
        let darkFailure = verifySnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .dark)),
            named: "\(name).dark",
            record: false,
            file: file,
            testName: testName
        )
        #expect(darkFailure == nil)
#endif
    }

    @Test
    func podcastTranscriptDetailViewTurnList() {
        let view = NavigationStack {
            PodcastTranscriptDetailView(
                store: Store(
                    initialState: PodcastTranscriptDetailFeature.State(
                        transcript: """
                        Alex (Male): First line.
                        Mia (Female): Second line.
                        """,
                        turns: [
                            PodcastTranscriptTurnTiming(
                                speaker: "Alex (Male)",
                                text: "First line.",
                                startSeconds: 0,
                                endSeconds: 5
                            ),
                            PodcastTranscriptTurnTiming(
                                speaker: "Mia (Female)",
                                text: "Second line.",
                                startSeconds: 5,
                                endSeconds: 11
                            )
                        ]
                    )
                ) {
                    PodcastTranscriptDetailFeature()
                }
            )
        }
#if os(macOS)
        .frame(width: 500, height: 800)
#elseif os(iOS) || os(tvOS)
        .frame(width: 390, height: 844)
#endif

        assertSnapshots(view, name: "turnList")
    }

    @Test
    func podcastTranscriptDetailViewRawTranscriptFallback() {
        let view = NavigationStack {
            PodcastTranscriptDetailView(
                store: Store(
                    initialState: PodcastTranscriptDetailFeature.State(
                        transcript: """
                        Alex (Male): First line.
                        Mia (Female): Second line.
                        """,
                        turns: []
                    )
                ) {
                    PodcastTranscriptDetailFeature()
                }
            )
        }
#if os(macOS)
        .frame(width: 500, height: 800)
#elseif os(iOS) || os(tvOS)
        .frame(width: 390, height: 844)
#endif

        assertSnapshots(view, name: "rawTranscriptFallback")
    }
}
