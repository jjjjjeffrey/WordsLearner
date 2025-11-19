//
//  ResponseDetailFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import ComposableArchitecture
import Foundation

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
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case comparisonCompleted(ComparisonHistory)
        }
    }
    
    @Dependency(\.aiService) var aiService
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
                
                let prompt = buildPrompt(
                    word1: state.word1,
                    word2: state.word2,
                    sentence: state.sentence
                )
                
                return .run { send in
                    do {
                        for try await chunk in aiService.streamResponse(prompt) {
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
                
                let comparison = ComparisonHistory(
                    word1: state.word1,
                    word2: state.word2,
                    sentence: state.sentence,
                    response: state.streamingResponse,
                    date: now
                )
                
                return .send(.delegate(.comparisonCompleted(comparison)))
                
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
                
            case .delegate:
                return .none
            }
        }
    }
}

private func buildPrompt(word1: String, word2: String, sentence: String) -> String {
    return """
    Help me compare the target English vocabularies "\(word1)" and "\(word2)" by telling me some simple stories that reveal what their means naturally in that specific context. And what's the key difference between them. These stories should illustrate not only the literal meaning but also the figurative meaning, if applicable.
    
    I'm an English learner, so tell this story at an elementary third-grade level, using only simple words and sentences, and without slang, phrasal verbs, or complex grammar.
    
    After the story, give any background or origin information (if it's known or useful), and explain the meaning of the vocabulary clearly.
    
    Finally, give 10 numbered example sentences that show the phrase used today in each context, with different tenses and sentence types, including questions. Use **bold** formatting for the target vocabulary throughout.

    If there are some situations we can use both of them without changing the meaning, and some other contexts which they can't be used interchangeably, please give me examples separately.

    At the end, tell me that if I can use them interchangeably in this sentence "\(sentence)"
    
    IMPORTANT: Format your response using proper Markdown syntax:
    - Use ## for main headings
    - Use ### for subheadings  
    - Use **text** for bold formatting
    - Use numbered lists (1. 2. 3.) for examples
    - Use - for bullet points when appropriate
    """
}

