//
//  ResponseDetailFeatureTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 11/18/25.
//

import Foundation
import ComposableArchitecture
import Testing
import DependenciesTestSupport

@testable import WordsLearner

@MainActor
struct ResponseDetailFeatureTests {
    
    // MARK: - onAppear Action Tests
    
    @Test
    func testOnAppearWithShouldStartStreamingTrue() async {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            shouldStartStreaming: true
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .init(
                generateComparison: { _, _, _ in stream },
                saveToHistory: { @Sendable _, _, _, _ async throws in
                    await Task.yield()
                }
            )
        }
        
        await store.send(.onAppear)
        
        await store.receive(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
        }
        
        // Send first chunk
        continuation.yield("First chunk ")
        await store.receive(.streamChunkReceived("First chunk ")) {
            $0.streamingResponse = "First chunk "
        }
        
        // Complete the stream
        continuation.finish()
        await store.receive(.streamCompleted) {
            $0.isStreaming = false
        }
        
        // Verify saveToHistory was called and comparisonSaved is received
        await store.receive(.comparisonSaved)
        
        await store.finish()
    }
    
    @Test
    func testOnAppearWithShouldStartStreamingFalse() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }
        
        await store.send(.onAppear)
        // Should not send any action when shouldStartStreaming is false
    }
    
    // MARK: - Streaming Flow Tests
    
    @Test
    func testStartStreamingSuccess() async {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence"
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .init(
                generateComparison: { _, _, _ in stream },
                saveToHistory: { @Sendable _, _, _, _ async throws in
                    await Task.yield()
                }
            )
        }
        
        await store.send(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
        }
        
        // Send first chunk
        continuation.yield("First chunk ")
        await store.receive(.streamChunkReceived("First chunk ")) {
            $0.streamingResponse = "First chunk "
        }
        
        // Send second chunk
        continuation.yield("Second chunk ")
        await store.receive(.streamChunkReceived("Second chunk ")) {
            $0.streamingResponse = "First chunk Second chunk "
        }
        
        // Send third chunk
        continuation.yield("Third chunk")
        await store.receive(.streamChunkReceived("Third chunk")) {
            $0.streamingResponse = "First chunk Second chunk Third chunk"
        }
        
        // Complete the stream
        continuation.finish()
        await store.receive(.streamCompleted) {
            $0.isStreaming = false
        }
        
        // Verify saveToHistory was called and comparisonSaved is received
        await store.receive(.comparisonSaved)
    }
    
    @Test
    func testStreamChunkReceived() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            streamingResponse: "Initial "
        )) {
            ResponseDetailFeature()
        }
        
        await store.send(.streamChunkReceived("chunk1 ")) {
            $0.streamingResponse = "Initial chunk1 "
        }
        
        await store.send(.streamChunkReceived("chunk2 ")) {
            $0.streamingResponse = "Initial chunk1 chunk2 "
        }
        
        await store.send(.streamChunkReceived("chunk3")) {
            $0.streamingResponse = "Initial chunk1 chunk2 chunk3"
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func testStreamFailed() async {
        struct StreamError: Error {
            let message: String
            var localizedDescription: String { message }
        }
        
        let error = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Stream failed"]
        )
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence"
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .init(
                generateComparison: { _, _, _ in stream },
                saveToHistory: { @Sendable _, _, _, _ async throws in
                    await Task.yield()
                }
            )
        }
        
        await store.send(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
        }
        
        // Send an error
        continuation.finish(throwing: error)
        await store.receive(.streamFailed("Stream failed")) {
            $0.isStreaming = false
            $0.errorMessage = "Stream failed"
        }
    }
    
    @Test
    func testComparisonSaveFailed() async {
        struct SaveError: Error {
            let message: String
            var localizedDescription: String { message }
        }

        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence"
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .init(
                generateComparison: { _, _, _ in stream },
                saveToHistory: { @Sendable _, _, _, _ async throws in
                    throw NSError(
                        domain: "test",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Database error"]
                    )
                }
            )
        }
        
        await store.send(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
        }
        
        // Send a chunk
        continuation.yield("Test response")
        await store.receive(.streamChunkReceived("Test response")) {
            $0.streamingResponse = "Test response"
        }
        
        // Complete the stream
        continuation.finish()
        await store.receive(.streamCompleted) {
            $0.isStreaming = false
        }
        
        // Verify save failed
        await store.receive(.comparisonSaveFailed("Database error")) {
            $0.errorMessage = "Failed to save comparison: Database error"
        }
    }
    
    // MARK: - Save to History Tests
    
    @Test
    func testComparisonSaved() async {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        var saveCalled = false
        var savedWord1: String?
        var savedWord2: String?
        var savedSentence: String?
        var savedResponse: String?
        
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence"
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .init(
                generateComparison: { _, _, _ in stream },
                saveToHistory: { @Sendable word1, word2, sentence, response async throws in
                    saveCalled = true
                    savedWord1 = word1
                    savedWord2 = word2
                    savedSentence = sentence
                    savedResponse = response
                    await Task.yield()
                }
            )
        }
        
        await store.send(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
        }
        
        // Send chunks
        continuation.yield("Response ")
        await store.receive(.streamChunkReceived("Response ")) {
            $0.streamingResponse = "Response "
        }
        
        continuation.yield("text")
        await store.receive(.streamChunkReceived("text")) {
            $0.streamingResponse = "Response text"
        }
        
        // Complete the stream
        continuation.finish()
        await store.receive(.streamCompleted) {
            $0.isStreaming = false
        }
        
        // Verify save was called with correct parameters
        await store.receive(.comparisonSaved)
        
        #expect(saveCalled == true)
        #expect(savedWord1 == "word1")
        #expect(savedWord2 == "word2")
        #expect(savedSentence == "This is a sentence")
        #expect(savedResponse == "Response text")
    }
    
    // MARK: - Share Functionality Test
    
    @Test
    func testShareButtonTapped() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "character",
            word2: "characteristic",
            sentence: "This is a test sentence",
            streamingResponse: "This is the analysis response"
        )) {
            ResponseDetailFeature()
        }
        
        await store.send(.shareButtonTapped)
        
        // Verify the action is handled (PlatformShareService.share is called)
        // Since it's a static method, we can't easily verify the exact text,
        // but we can verify the action completes without errors
    }
}
