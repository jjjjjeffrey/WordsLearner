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
        var currentSpeakerTurnIndex: Int? = nil
        var currentSpeakerTurnText: String? = nil
        @Presents var markdownDetail: MarkdownDetailFeature.State?
        @Presents var transcriptDetail: PodcastTranscriptDetailFeature.State?
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
        case audioPlaybackSnapshotReceived(ComparisonAudioPlaybackClient.Snapshot)
        case audioPlaybackEventReceived(ComparisonAudioPlaybackClient.Event)
        case audioRemoteCommandReceived(ComparisonAudioRemoteControlClient.Command)
        case audioJumpToPreviousTurn
        case audioJumpToNextTurn
        case audioJumpToTurn(Int)
        case audioPlaybackStarted
        case audioPlaybackProgressUpdated(Double)
        case audioPlaybackPaused
        case audioPlaybackFinished
        case audioPlaybackStopped
        case generatePodcastTranscriptButtonTapped
        case podcastTranscriptSucceeded(String)
        case podcastTranscriptFailed(String)
        case markdownDetailButtonTapped
        case transcriptDetailButtonTapped
        case markdownDetail(PresentationAction<MarkdownDetailFeature.Action>)
        case transcriptDetail(PresentationAction<PodcastTranscriptDetailFeature.Action>)
    }
    
    @Dependency(\.comparisonGenerator) var generator
    @Dependency(\.comparisonAudioService) var comparisonAudioService
    @Dependency(ComparisonPodcastTranscriptClient.self) var comparisonPodcastTranscript
    @Dependency(\.comparisonAudioAssetStore) var comparisonAudioAssetStore
    @Dependency(\.comparisonAudioPlayback) var comparisonAudioPlayback
    @Dependency(\.comparisonAudioRemoteControl) var comparisonAudioRemoteControl
    @Dependency(\.platformShare) var platformShare

    enum CancelID: Sendable {
        case playbackEvents
        case remoteCommands
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                var effects: [Effect<Action>] = [
                    .run { [comparisonAudioPlayback] send in
                        let snapshot = await comparisonAudioPlayback.snapshot()
                        await send(.audioPlaybackSnapshotReceived(snapshot))
                    },
                    .run { [comparisonAudioPlayback] send in
                        let events = await comparisonAudioPlayback.events()
                        for await event in events {
                            await send(.audioPlaybackEventReceived(event))
                        }
                    }
                    .cancellable(id: CancelID.playbackEvents, cancelInFlight: true),
                    .run { [comparisonAudioRemoteControl] send in
                        let commands = await comparisonAudioRemoteControl.commands()
                        for await command in commands {
                            await send(.audioRemoteCommandReceived(command))
                        }
                    }
                    .cancellable(id: CancelID.remoteCommands, cancelInFlight: true)
                ]
                if state.shouldStartStreaming, !state.isStreaming, state.streamingResponse.isEmpty {
                    effects.append(.send(.startStreaming))
                }
                if !state.streamingResponse.isEmpty, state.attributedString.characters.isEmpty {
                    effects.append(.send(.hydrateStoredResponse))
                }
                effects.append(updateNowPlayingEffect(state, remoteControl: comparisonAudioRemoteControl))
                return .merge(effects)

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
                state.currentSpeakerTurnIndex = nil
                state.currentSpeakerTurnText = nil
                return .merge(
                    .run { [comparisonAudioPlayback] _ in
                        await comparisonAudioPlayback.stop(true)
                    },
                    .run {
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
                )

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
                return .send(.audioPlaybackToggled)

            case let .audioGenerationFailed(message):
                state.isGeneratingAudio = false
                state.isGeneratingPodcastTranscript = false
                state.audioGenerationProgress = 0
                state.audioGenerationStatusMessage = nil
                state.audioErrorMessage = message
                return .none

            case .audioPlaybackToggled:
                state.shouldAutoPlayAfterAudioReady = false
                guard let relativePath = state.audioRelativePath else { return .none }
                if state.isAudioPlaying {
                    return .run {
                        [
                            comparisonAudioPlayback,
                            comparisonAudioRemoteControl,
                            word1 = state.word1,
                            word2 = state.word2,
                            sentence = state.sentence,
                            currentSpeakerTurnText = state.currentSpeakerTurnText,
                            audioDurationSeconds = state.audioDurationSeconds,
                            currentAudioTimeSeconds = state.currentAudioTimeSeconds
                        ] _ in
                        await comparisonAudioPlayback.pause()
                        await comparisonAudioRemoteControl.updateNowPlaying(
                            makeNowPlayingMetadata(
                                title: "\(word1) vs \(word2)",
                                subtitle: currentSpeakerTurnText ?? sentence,
                                durationSeconds: audioDurationSeconds,
                                elapsedTimeSeconds: currentAudioTimeSeconds,
                                isPlaying: false
                            )
                        )
                    }
                }
                return .run {
                    [
                        comparisonAudioAssetStore,
                        comparisonAudioPlayback,
                        comparisonAudioRemoteControl,
                        relativePath,
                        currentTimeSeconds = state.currentAudioTimeSeconds,
                        word1 = state.word1,
                        word2 = state.word2,
                        sentence = state.sentence,
                        currentSpeakerTurnText = state.currentSpeakerTurnText,
                        audioDurationSeconds = state.audioDurationSeconds
                    ] _ in
                    guard let data = try? comparisonAudioAssetStore.loadAudioData(relativePath) else { return }
                    await comparisonAudioRemoteControl.activateAudioSession()
                    await comparisonAudioRemoteControl.updateNowPlaying(
                        makeNowPlayingMetadata(
                            title: "\(word1) vs \(word2)",
                            subtitle: currentSpeakerTurnText ?? sentence,
                            durationSeconds: audioDurationSeconds,
                            elapsedTimeSeconds: currentTimeSeconds,
                            isPlaying: true
                        )
                    )
                    await comparisonAudioPlayback.play(data, relativePath, currentTimeSeconds)
                }

            case let .audioPlaybackSnapshotReceived(snapshot):
                guard snapshot.sourceID == state.audioRelativePath else {
                    state.isAudioPlaying = false
                    return .none
                }
                state.currentAudioTimeSeconds = snapshot.currentTimeSeconds
                state.isAudioPlaying = snapshot.isPlaying
                updateActiveSpeakerTurn(state: &state)
                return updateNowPlayingEffect(state, remoteControl: comparisonAudioRemoteControl)

            case let .audioPlaybackEventReceived(event):
                switch event {
                case let .started(sourceID, currentTimeSeconds):
                    guard sourceID == state.audioRelativePath else { return .none }
                    state.shouldAutoPlayAfterAudioReady = false
                    state.isAudioPlaying = true
                    state.currentAudioTimeSeconds = currentTimeSeconds
                    updateActiveSpeakerTurn(state: &state)
                    return updateNowPlayingEffect(state, remoteControl: comparisonAudioRemoteControl)

                case let .progressUpdated(sourceID, currentTimeSeconds):
                    guard sourceID == state.audioRelativePath else { return .none }
                    state.currentAudioTimeSeconds = max(0, currentTimeSeconds)
                    updateActiveSpeakerTurn(state: &state)
                    return updateNowPlayingEffect(state, remoteControl: comparisonAudioRemoteControl)

                case let .paused(sourceID, currentTimeSeconds):
                    guard sourceID == state.audioRelativePath else { return .none }
                    state.shouldAutoPlayAfterAudioReady = false
                    state.isAudioPlaying = false
                    state.currentAudioTimeSeconds = currentTimeSeconds
                    updateActiveSpeakerTurn(state: &state)
                    return updateNowPlayingEffect(state, remoteControl: comparisonAudioRemoteControl)

                case .stopped:
                    state.shouldAutoPlayAfterAudioReady = false
                    state.isAudioPlaying = false
                    state.currentAudioTimeSeconds = 0
                    state.currentSpeakerTurnIndex = nil
                    state.currentSpeakerTurnText = nil
                    return .run { [comparisonAudioRemoteControl] _ in
                        await comparisonAudioRemoteControl.clearNowPlaying()
                    }

                case let .finished(sourceID):
                    guard sourceID == state.audioRelativePath else { return .none }
                    state.shouldAutoPlayAfterAudioReady = false
                    state.isAudioPlaying = false
                    state.currentAudioTimeSeconds = 0
                    state.currentSpeakerTurnIndex = nil
                    state.currentSpeakerTurnText = nil
                    return .run { [comparisonAudioRemoteControl] _ in
                        await comparisonAudioRemoteControl.clearNowPlaying()
                    }
                }

            case let .audioRemoteCommandReceived(command):
                switch command {
                case .togglePlayPause:
                    return .send(.audioPlaybackToggled)
                case .play:
                    return state.isAudioPlaying ? .none : .send(.audioPlaybackToggled)
                case .pause:
                    return state.isAudioPlaying ? .send(.audioPlaybackToggled) : .none
                case .previous:
                    return .send(.audioJumpToPreviousTurn)
                case .next:
                    return .send(.audioJumpToNextTurn)
                }

            case .audioJumpToPreviousTurn:
                guard let activeTurnIndex = state.currentSpeakerTurnIndex, activeTurnIndex > 0 else {
                    return .none
                }
                return .send(.audioJumpToTurn(activeTurnIndex - 1))

            case .audioJumpToNextTurn:
                guard let activeTurnIndex = state.currentSpeakerTurnIndex, activeTurnIndex + 1 < state.transcriptTurnTimings.count else {
                    return .none
                }
                return .send(.audioJumpToTurn(activeTurnIndex + 1))

            case let .audioJumpToTurn(index):
                guard
                    state.transcriptTurnTimings.indices.contains(index),
                    let relativePath = state.audioRelativePath,
                    let data = try? comparisonAudioAssetStore.loadAudioData(relativePath)
                else {
                    return .none
                }
                let targetTime = state.transcriptTurnTimings[index].startSeconds
                state.currentAudioTimeSeconds = targetTime
                updateActiveSpeakerTurn(state: &state)
                return .run {
                    [
                        comparisonAudioPlayback,
                        comparisonAudioRemoteControl,
                        data,
                        relativePath,
                        targetTime,
                        word1 = state.word1,
                        word2 = state.word2,
                        currentSpeakerTurnText = state.currentSpeakerTurnText,
                        sentence = state.sentence,
                        audioDurationSeconds = state.audioDurationSeconds
                    ] _ in
                    await comparisonAudioRemoteControl.activateAudioSession()
                    await comparisonAudioRemoteControl.updateNowPlaying(
                        makeNowPlayingMetadata(
                            title: "\(word1) vs \(word2)",
                            subtitle: currentSpeakerTurnText ?? sentence,
                            durationSeconds: audioDurationSeconds,
                            elapsedTimeSeconds: targetTime,
                            isPlaying: true
                        )
                    )
                    await comparisonAudioPlayback.play(data, relativePath, targetTime)
                }

            case .audioPlaybackStarted:
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = true
                updateActiveSpeakerTurn(state: &state)
                return .none

            case let .audioPlaybackProgressUpdated(currentTime):
                state.currentAudioTimeSeconds = max(0, currentTime)
                updateActiveSpeakerTurn(state: &state)
                return .none

            case .audioPlaybackPaused:
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = false
                return .none

            case .audioPlaybackFinished:
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = false
                state.currentAudioTimeSeconds = 0
                state.currentSpeakerTurnIndex = nil
                state.currentSpeakerTurnText = nil
                return .none

            case .audioPlaybackStopped:
                state.shouldAutoPlayAfterAudioReady = false
                state.isAudioPlaying = false
                state.currentSpeakerTurnIndex = nil
                state.currentSpeakerTurnText = nil
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

            case .transcriptDetailButtonTapped:
                guard
                    !state.podcastTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !state.transcriptTurnTimings.isEmpty
                else {
                    return .none
                }
                state.transcriptDetail = PodcastTranscriptDetailFeature.State(
                    transcript: state.podcastTranscript,
                    turns: state.transcriptTurnTimings
                )
                return .none

            case .markdownDetail:
                return .none

            case .transcriptDetail:
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
        .ifLet(\.$transcriptDetail, action: \.transcriptDetail) {
            PodcastTranscriptDetailFeature()
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

private func activeSpeakerTurnIndex(
    for timeSeconds: Double,
    timings: [PodcastTranscriptTurnTiming]
) -> Int? {
    guard !timings.isEmpty else { return nil }
    if let exactIndex = timings.firstIndex(where: { $0.contains(timeSeconds: timeSeconds) }) {
        return exactIndex
    }
    return timings.lastIndex(where: { timeSeconds >= $0.startSeconds })
}

private func updateActiveSpeakerTurn(state: inout ResponseDetailFeature.State) {
    guard let index = activeSpeakerTurnIndex(
        for: state.currentAudioTimeSeconds,
        timings: state.transcriptTurnTimings
    ) else {
        state.currentSpeakerTurnIndex = nil
        state.currentSpeakerTurnText = nil
        return
    }

    state.currentSpeakerTurnIndex = index
    state.currentSpeakerTurnText = state.transcriptTurnTimings[index].displayText
}

private func updateNowPlayingEffect(
    _ state: ResponseDetailFeature.State,
    remoteControl: ComparisonAudioRemoteControlClient
) -> Effect<ResponseDetailFeature.Action> {
    guard state.audioRelativePath != nil else {
        return .run { _ in
            await remoteControl.clearNowPlaying()
        }
    }
    let metadata = makeNowPlayingMetadata(
        title: "\(state.word1) vs \(state.word2)",
        subtitle: state.currentSpeakerTurnText ?? state.sentence,
        durationSeconds: state.audioDurationSeconds,
        elapsedTimeSeconds: state.currentAudioTimeSeconds,
        isPlaying: state.isAudioPlaying
    )
    return .run { _ in
        await remoteControl.updateNowPlaying(metadata)
    }
}

private func makeNowPlayingMetadata(
    title: String,
    subtitle: String,
    durationSeconds: Double?,
    elapsedTimeSeconds: Double,
    isPlaying: Bool
) -> ComparisonAudioRemoteControlClient.Metadata {
    ComparisonAudioRemoteControlClient.Metadata(
        title: title,
        subtitle: subtitle,
        durationSeconds: durationSeconds,
        elapsedTimeSeconds: elapsedTimeSeconds,
        isPlaying: isPlaying
    )
}
