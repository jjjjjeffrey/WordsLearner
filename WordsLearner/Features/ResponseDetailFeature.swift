//
//  ResponseDetailFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct ResponseDetailFeature {
    @ObservableState
    struct State: Equatable {
        let word1: String
        let word2: String
        let sentence: String
        var comparisonID: UUID? = nil
        var streamingResponse: String = ""
        var attributedString: AttributedString = AttributedString()
        var scrollToBottomId: Int = 0
        var isStreaming: Bool = false
        var errorMessage: String? = nil
        var shouldStartStreaming: Bool = true
        var audioRelativePath: String? = nil
        var audioDurationSeconds: Double? = nil
        var isGeneratingAudio: Bool = false
        var audioGenerationProgress: Double = 0
        var audioGenerationStatusMessage: String? = nil
        var audioErrorMessage: String? = nil
        var shouldAutoPlayAfterAudioReady: Bool = false
        var podcastTranscript: String = ""
        var isGeneratingPodcastTranscript: Bool = false
        var podcastTranscriptErrorMessage: String? = nil
        var transcriptTurnTimings: [PodcastTranscriptTurnTiming] = []
        var isAudioPlaying: Bool = false
        var currentAudioTimeSeconds: Double = 0
        var currentSpeakerTurnText: String? = nil
        @Presents var markdownDetail: MarkdownDetailFeature.State?
    }
    
    enum Action: Equatable {
        case onAppear
        case hydrateStoredResponse
        case startStreaming
        case streamChunkReceived(String)
        case streamCompleted
        case attributedStringRendered(AttributedString)
        case streamFailed(String)
        case shareButtonTapped
        case comparisonSaved(UUID)
        case comparisonSaveFailed(String)
        case generateAudioButtonTapped
        case audioGenerationProgressUpdated(Double, String)
        case audioGenerationSucceeded(ComparisonAudioMetadata)
        case audioGenerationFailed(String)
        case audioPlaybackToggled
        case audioPlaybackStarted
        case audioPlaybackProgressUpdated(Double)
        case audioPlaybackPaused
        case audioPlaybackFinished
        case audioPlaybackStopped
        case generatePodcastTranscriptButtonTapped
        case podcastTranscriptSucceeded(String)
        case podcastTranscriptFailed(String)
        case markdownDetailButtonTapped
        case markdownDetail(PresentationAction<MarkdownDetailFeature.Action>)
    }
    
    @Dependency(\.comparisonGenerator) var generator
    @Dependency(\.comparisonAudioService) var comparisonAudioService
    @Dependency(ComparisonPodcastTranscriptClient.self) var comparisonPodcastTranscript
    @Dependency(\.platformShare) var platformShare
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.shouldStartStreaming, !state.isStreaming, state.streamingResponse.isEmpty {
                    return .send(.startStreaming)
                }
                if !state.streamingResponse.isEmpty, state.attributedString.characters.isEmpty {
                    return .send(.hydrateStoredResponse)
                }
                return .none

            case .hydrateStoredResponse:
                guard !state.streamingResponse.isEmpty else {
                    return .none
                }
                return .run { [ streamingResponse = state.streamingResponse ] send in
                    let processed = await AttributedStringRenderer.renderMarkdown(streamingResponse)
                    await send(.attributedStringRendered(processed))
                }
                
            case .startStreaming:
                guard !state.isStreaming else { return .none }
                state.isStreaming = true
                state.shouldStartStreaming = false
                state.errorMessage = nil
                state.podcastTranscript = ""
                state.podcastTranscriptErrorMessage = nil
                
                return .run { [generator, word1 = state.word1, word2 = state.word2, sentence = state.sentence] send in
                    do {
                        for try await chunk in generator.generateComparison(word1, word2, sentence) {
                            await send(.streamChunkReceived(chunk))
                        }
                        await send(.streamCompleted)
                    } catch {
                        await send(.streamFailed(error.localizedDescription))
                    }
                }
                
            case let .streamChunkReceived(chunk):
                state.streamingResponse += chunk
                if var markdownDetail = state.markdownDetail {
                    markdownDetail.markdown = state.streamingResponse
                    state.markdownDetail = markdownDetail
                }
                return .run { [ streamingResponse = state.streamingResponse ] send in
                    let processed = await AttributedStringRenderer.renderMarkdown(streamingResponse)
                    await send(.attributedStringRendered(processed))
                }
            case let .attributedStringRendered(attributedString):
                state.attributedString = attributedString
                if state.isStreaming { state.scrollToBottomId+=1 }
                if var markdownDetail = state.markdownDetail {
                    markdownDetail.attributedString = attributedString
                    state.markdownDetail = markdownDetail
                }
                return .none
            case .streamCompleted:
                state.isStreaming = false
                return .run { [generator, word1 = state.word1, word2 = state.word2, sentence = state.sentence, response = state.streamingResponse] send in
                    do {
                        let id = try await generator.saveToHistory(
                            word1,
                            word2,
                            sentence,
                            response
                        )
                        await send(.comparisonSaved(id))
                    } catch {
                        await send(.comparisonSaveFailed(error.localizedDescription))
                    }
                }
                
            case let .comparisonSaved(id):
                state.comparisonID = id
                return .none
                
            case let .comparisonSaveFailed(errorMessage):
                state.errorMessage = "Failed to save comparison: \(errorMessage)"
                return .none
                
            case let .streamFailed(errorMessage):
                state.isStreaming = false
                state.errorMessage = errorMessage
                return .none

            case .generateAudioButtonTapped:
                guard
                    let comparisonID = state.comparisonID,
                    !state.streamingResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    !state.isGeneratingAudio
                else {
                    return .none
                }
                state.isGeneratingAudio = true
                state.isGeneratingPodcastTranscript = true
                state.audioGenerationProgress = 0.05
                state.audioGenerationStatusMessage = "Generating podcast transcript..."
                state.audioErrorMessage = nil
                state.podcastTranscriptErrorMessage = nil
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = false
                state.currentAudioTimeSeconds = 0
                state.currentSpeakerTurnText = nil
                return .run {
                    [
                        comparisonAudioService,
                        comparisonPodcastTranscript,
                        markdown = state.streamingResponse
                    ] send in
                    do {
                        await send(.audioGenerationProgressUpdated(0.2, "Generating podcast transcript..."))
                        let transcript = try await comparisonPodcastTranscript.generateTranscript(markdown)
                        await send(.podcastTranscriptSucceeded(transcript))
                        await send(.audioGenerationProgressUpdated(0.6, "Generating audio..."))
                        let metadata = try await comparisonAudioService.generateAndAttach(comparisonID, transcript)
                        await send(.audioGenerationSucceeded(metadata))
                    } catch {
                        await send(.audioGenerationFailed(error.localizedDescription))
                    }
                }

            case let .audioGenerationProgressUpdated(progress, message):
                state.audioGenerationProgress = max(0, min(1, progress))
                state.audioGenerationStatusMessage = message
                return .none

            case let .audioGenerationSucceeded(metadata):
                state.isGeneratingAudio = false
                state.isGeneratingPodcastTranscript = false
                state.audioGenerationProgress = 1
                state.audioGenerationStatusMessage = "Completed"
                state.audioRelativePath = metadata.relativePath
                state.audioDurationSeconds = metadata.durationSeconds
                state.transcriptTurnTimings = metadata.transcriptTurnTimings
                state.audioErrorMessage = nil
                state.shouldAutoPlayAfterAudioReady = true
                return .none

            case let .audioGenerationFailed(message):
                state.isGeneratingAudio = false
                state.isGeneratingPodcastTranscript = false
                state.audioGenerationProgress = 0
                state.audioGenerationStatusMessage = nil
                state.audioErrorMessage = message
                return .none

            case .audioPlaybackToggled:
                state.shouldAutoPlayAfterAudioReady = false
                return .none

            case .audioPlaybackStarted:
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = true
                if let currentTurn = activeSpeakerTurn(for: state.currentAudioTimeSeconds, timings: state.transcriptTurnTimings) {
                    state.currentSpeakerTurnText = currentTurn.displayText
                }
                return .none

            case let .audioPlaybackProgressUpdated(currentTime):
                state.currentAudioTimeSeconds = max(0, currentTime)
                if let currentTurn = activeSpeakerTurn(
                    for: state.currentAudioTimeSeconds,
                    timings: state.transcriptTurnTimings
                ) {
                    state.currentSpeakerTurnText = currentTurn.displayText
                }
                return .none

            case .audioPlaybackPaused:
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = false
                return .none

            case .audioPlaybackFinished:
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = false
                state.currentAudioTimeSeconds = 0
                state.currentSpeakerTurnText = nil
                return .none

            case .audioPlaybackStopped:
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = false
                return .none

            case .generatePodcastTranscriptButtonTapped:
                guard
                    !state.streamingResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    !state.isGeneratingPodcastTranscript
                else {
                    return .none
                }
                state.isGeneratingPodcastTranscript = true
                state.podcastTranscriptErrorMessage = nil
                return .run { [comparisonPodcastTranscript, markdown = state.streamingResponse] send in
                    do {
                        let transcript = try await comparisonPodcastTranscript.generateTranscript(markdown)
                        await send(.podcastTranscriptSucceeded(transcript))
                    } catch {
                        await send(.podcastTranscriptFailed(error.localizedDescription))
                    }
                }

            case let .podcastTranscriptSucceeded(transcript):
                state.isGeneratingPodcastTranscript = false
                state.podcastTranscript = transcript
                state.podcastTranscriptErrorMessage = nil
                return .none

            case let .podcastTranscriptFailed(message):
                state.isGeneratingPodcastTranscript = false
                state.podcastTranscriptErrorMessage = message
                return .none

            case .markdownDetailButtonTapped:
                guard !state.streamingResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .none
                }
                state.markdownDetail = MarkdownDetailFeature.State(
                    markdown: state.streamingResponse,
                    attributedString: state.attributedString
                )
                return .none

            case .markdownDetail:
                return .none

            case .shareButtonTapped:
                let shareText = """
                Word Comparison: \(state.word1) vs \(state.word2)
                
                Context: \(state.sentence)
                
                Analysis:
                \(state.streamingResponse)
                """
                
                platformShare.share(shareText)
                return .none
            }
        }
        .ifLet(\.$markdownDetail, action: \.markdownDetail) {
            MarkdownDetailFeature()
        }
    }
}

private func activeSpeakerTurn(
    for timeSeconds: Double,
    timings: [PodcastTranscriptTurnTiming]
) -> PodcastTranscriptTurnTiming? {
    guard !timings.isEmpty else { return nil }
    if let exact = timings.first(where: { $0.contains(timeSeconds: timeSeconds) }) {
        return exact
    }
    return timings.last(where: { timeSeconds >= $0.startSeconds })
}
