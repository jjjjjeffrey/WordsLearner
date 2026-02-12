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
        var streamingResponse: String = ""
        var attributedString: AttributedString = AttributedString()
        var scrollToBottomId: Int = 0
        var isStreaming: Bool = false
        var errorMessage: String? = nil
        var shouldStartStreaming: Bool = true
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
        case comparisonSaved
        case comparisonSaveFailed(String)
    }
    
    @Dependency(\.comparisonGenerator) var generator
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
                return .run { [ streamingResponse = state.streamingResponse ] send in
                    let processed = await AttributedStringRenderer.renderMarkdown(streamingResponse)
                    await send(.attributedStringRendered(processed))
                }
            case let .attributedStringRendered(attributedString):
                state.attributedString = attributedString
                if state.isStreaming { state.scrollToBottomId+=1 }
                return .none
            case .streamCompleted:
                state.isStreaming = false
                return .run { [generator, word1 = state.word1, word2 = state.word2, sentence = state.sentence, response = state.streamingResponse] send in
                    do {
                        try await generator.saveToHistory(
                            word1,
                            word2,
                            sentence,
                            response
                        )
                        await send(.comparisonSaved)
                    } catch {
                        await send(.comparisonSaveFailed(error.localizedDescription))
                    }
                }
                
            case .comparisonSaved:
                return .none
                
            case let .comparisonSaveFailed(errorMessage):
                state.errorMessage = "Failed to save comparison: \(errorMessage)"
                return .none
                
            case let .streamFailed(errorMessage):
                state.isStreaming = false
                state.errorMessage = errorMessage
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
    }
}
