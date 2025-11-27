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
        var isStreaming: Bool = false
        var errorMessage: String? = nil
        var shouldStartStreaming: Bool = true
    }
    
    enum Action {
        case onAppear
        case startStreaming
        case streamChunkReceived(String)
        case streamCompleted
        case streamFailed(Error)
        case shareButtonTapped
        case comparisonSaved
        case comparisonSaveFailed(Error)
    }
    
    @Dependency(\.comparisonGenerator) var generator
    @Dependency(\.date.now) var now
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.shouldStartStreaming else { return .none }
                return .send(.startStreaming)
                
            case .startStreaming:
                state.isStreaming = true
                state.errorMessage = nil
                
                return .run { [word1 = state.word1, word2 = state.word2, sentence = state.sentence] send in
                    do {
                        for try await chunk in generator.generateComparison(word1, word2, sentence) {
                            await send(.streamChunkReceived(chunk))
                        }
                        await send(.streamCompleted)
                    } catch {
                        await send(.streamFailed(error))
                    }
                }
                
            case let .streamChunkReceived(chunk):
                state.streamingResponse += chunk
                return .none
                
            case .streamCompleted:
                state.isStreaming = false
                
                return .run { [word1 = state.word1, word2 = state.word2, sentence = state.sentence, response = state.streamingResponse, now] send in
                    do {
                        try await generator.saveToHistory(
                            word1,
                            word2,
                            sentence,
                            response,
                            now
                        )
                        await send(.comparisonSaved)
                    } catch {
                        await send(.comparisonSaveFailed(error))
                    }
                }
                
            case .comparisonSaved:
                return .none
                
            case let .comparisonSaveFailed(error):
                state.errorMessage = "Failed to save comparison: \(error.localizedDescription)"
                return .none
                
            case let .streamFailed(error):
                state.isStreaming = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .shareButtonTapped:
                let shareText = """
                Word Comparison: \(state.word1) vs \(state.word2)
                
                Context: \(state.sentence)
                
                Analysis:
                \(state.streamingResponse)
                """
                
                PlatformShareService.share(text: shareText)
                return .none
            }
        }
    }
}
