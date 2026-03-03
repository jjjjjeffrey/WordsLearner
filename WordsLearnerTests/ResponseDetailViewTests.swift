//
//  ResponseDetailViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/16/26.
//

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
struct ResponseDetailViewTests {

    private func makeView(
        state: ResponseDetailFeature.State
    ) -> some View {
        let store = Store(initialState: state) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .testValue
        }

        return NavigationStack {
            ResponseDetailView(store: store)
        }
#if os(macOS)
        .frame(width: 500)
#elseif os(iOS) || os(tvOS)
        .frame(width: 390, height: 844)
#endif
    }

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
    func responseDetailViewEmptyResponse() async {
        let view = makeView(
            state: ResponseDetailFeature.State(
                word1: "character",
                word2: "characteristic",
                sentence: "This is a test sentence.",
                streamingResponse: "",
                isStreaming: false,
                errorMessage: nil,
                shouldStartStreaming: false
            )
        )
        assertSnapshots(view, name: "emptyResponse")
    }
    
    @Test
    func responseDetailViewWithResponse() async throws {
        let store = Store(
            initialState: ResponseDetailFeature.State(
                word1: "affect",
                word2: "effect",
                sentence: "The new policy will affect how the bonus takes effect.",
                streamingResponse: "",
                isStreaming: false,
                errorMessage: nil,
                shouldStartStreaming: true
            )
        ) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .testValue
        }

        store.send(.onAppear)
        while store.state.isStreaming || store.state.streamingResponse.isEmpty {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        let view = NavigationStack {
            ResponseDetailView(store: store)
        }
#if os(macOS)
            .frame(width: 500)
#elseif os(iOS) || os(tvOS)
            .frame(width: 390, height: 844)
#endif

        assertSnapshots(view, name: "withResponse")
    }

    @Test
    func responseDetailViewGeneratingAudioProgress() async {
        let view = makeView(
            state: ResponseDetailFeature.State(
                word1: "affect",
                word2: "effect",
                sentence: "The policy will affect the final effect.",
                comparisonID: UUID(),
                streamingResponse: "## Analysis\n\n- point 1\n- point 2",
                attributedString: AttributedString("Analysis"),
                shouldStartStreaming: false,
                isGeneratingAudio: true,
                audioGenerationProgress: 0.35,
                audioGenerationStatusMessage: "Generating podcast transcript...",
                podcastTranscript: "Alex (Male): Intro",
                isGeneratingPodcastTranscript: true
            )
        )
        assertSnapshots(view, name: "generatingAudio")
    }

    @Test
    func responseDetailViewAudioReadyWithTranscriptAndMarkdownLink() async {
        let view = makeView(
            state: ResponseDetailFeature.State(
                word1: "affect",
                word2: "effect",
                sentence: "The policy will affect the final effect.",
                comparisonID: UUID(),
                streamingResponse: "## Analysis\n\n- point 1\n- point 2",
                attributedString: AttributedString("Analysis"),
                shouldStartStreaming: false,
                audioRelativePath: "ComparisonAudio/ready.m4a",
                audioDurationSeconds: 93,
                podcastTranscript: """
                Alex (Male): Let's walk through this.
                Mia (Female): Great, let's cover every example.
                """
            )
        )
        assertSnapshots(view, name: "audioReady")
    }

    @Test
    func responseDetailViewAudioAndTranscriptErrors() async {
        let view = makeView(
            state: ResponseDetailFeature.State(
                word1: "affect",
                word2: "effect",
                sentence: "The policy will affect the final effect.",
                comparisonID: UUID(),
                streamingResponse: "## Analysis\n\n- point 1\n- point 2",
                attributedString: AttributedString("Analysis"),
                shouldStartStreaming: false,
                audioErrorMessage: "Network connection failed",
                podcastTranscriptErrorMessage: "Transcript generation failed"
            )
        )
        assertSnapshots(view, name: "audioErrors")
    }
}
