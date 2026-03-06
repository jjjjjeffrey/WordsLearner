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
        assertSnapshots(view, name: "generatingAudioV2")
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
        assertSnapshots(view, name: "audioReadyV2")
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

    @Test
    func responseDetailViewAudioPlaybackNowSpeaking() async {
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
                """,
                transcriptTurnTimings: [
                    PodcastTranscriptTurnTiming(
                        speaker: "Alex (Male)",
                        text: "Let's walk through this.",
                        startSeconds: 0,
                        endSeconds: 42
                    ),
                    PodcastTranscriptTurnTiming(
                        speaker: "Mia (Female)",
                        text: "Great, let's cover every example.",
                        startSeconds: 42,
                        endSeconds: 93
                    ),
                ],
                isAudioPlaying: true,
                currentAudioTimeSeconds: 20,
                currentSpeakerTurnText: "Alex (Male): Let's walk through this."
            )
        )
        assertSnapshots(view, name: "audioPlaybackNowSpeaking")
    }

    @Test
    func responseDetailViewAudioPlaybackPausedAtCurrentTurn() async {
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
                """,
                transcriptTurnTimings: [
                    PodcastTranscriptTurnTiming(
                        speaker: "Alex (Male)",
                        text: "Let's walk through this.",
                        startSeconds: 0,
                        endSeconds: 42
                    ),
                    PodcastTranscriptTurnTiming(
                        speaker: "Mia (Female)",
                        text: "Great, let's cover every example.",
                        startSeconds: 42,
                        endSeconds: 93
                    ),
                ],
                isAudioPlaying: false,
                currentAudioTimeSeconds: 60,
                currentSpeakerTurnText: "Mia (Female): Great, let's cover every example."
            )
        )
        assertSnapshots(view, name: "audioPlaybackPausedAt")
    }

    @Test
    func responseDetailViewAudioPlaybackFinishedClearsCurrentTurn() async {
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
                """,
                transcriptTurnTimings: [
                    PodcastTranscriptTurnTiming(
                        speaker: "Alex (Male)",
                        text: "Let's walk through this.",
                        startSeconds: 0,
                        endSeconds: 42
                    ),
                    PodcastTranscriptTurnTiming(
                        speaker: "Mia (Female)",
                        text: "Great, let's cover every example.",
                        startSeconds: 42,
                        endSeconds: 93
                    ),
                ],
                isAudioPlaying: false,
                currentAudioTimeSeconds: 0,
                currentSpeakerTurnText: nil
            )
        )
        assertSnapshots(view, name: "audioPlaybackFinishedCleared")
    }

    @Test
    func responseDetailViewAudioRegeneratingAfterPlaybackReset() async {
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
                isGeneratingAudio: true,
                audioGenerationProgress: 0.6,
                audioGenerationStatusMessage: "Generating audio...",
                podcastTranscript: """
                Alex (Male): Let's walk through this.
                Mia (Female): Great, let's cover every example.
                """,
                isGeneratingPodcastTranscript: true,
                transcriptTurnTimings: [],
                isAudioPlaying: false,
                currentAudioTimeSeconds: 0,
                currentSpeakerTurnText: nil
            )
        )
        assertSnapshots(view, name: "audioRegeneratingReset")
    }
}
