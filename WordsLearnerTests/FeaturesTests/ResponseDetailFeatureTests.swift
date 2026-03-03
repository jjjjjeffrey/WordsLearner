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
        let savedID = UUID()
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
                    return savedID
                }
            )
        }
        
        await store.send(.onAppear)
        
        await store.receive(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
            $0.shouldStartStreaming = false
        }
        
        // Send first chunk
        let string = "First chunk "
        continuation.yield(string)
        await store.receive(.streamChunkReceived(string)) {
            $0.streamingResponse = string
        }
        
        // Complete the stream
        continuation.finish()
        let rendered = await AttributedStringRenderer.renderMarkdown(string)
        await store.receive(.attributedStringRendered(rendered)) {
            $0.attributedString = rendered
            $0.scrollToBottomId += 1
        }
        
        await store.receive(.streamCompleted) {
            $0.isStreaming = false
        }
        
        // Verify saveToHistory was called and comparisonSaved is received
        await store.receive(.comparisonSaved(savedID)) {
            $0.comparisonID = savedID
        }
        
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
    }
    
    @Test
    func testOnAppearWithShouldNotStartStreamingWithExistingStreamResponse() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            streamingResponse: "This is a streamingResponse",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }
        
        await store.send(.onAppear)
        await store.receive(.hydrateStoredResponse)
        let rendered = await AttributedStringRenderer.renderMarkdown("This is a streamingResponse")
        await store.receive(.attributedStringRendered(rendered)) {
            $0.attributedString = rendered
        }
    }
    
    // MARK: - Streaming Flow Tests
    
    @Test
    func testStartStreamingSuccess() async {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        let savedID = UUID()
        
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
                    return savedID
                }
            )
        }
        
        await store.send(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
            $0.shouldStartStreaming = false
        }
        
        // Send first chunk
        let firstChunk = "First chunk "
        continuation.yield(firstChunk)
        await store.receive(.streamChunkReceived(firstChunk)) {
            $0.streamingResponse = firstChunk
        }
        
        let firstChunkRendered = await AttributedStringRenderer.renderMarkdown(firstChunk)
        await store.receive(.attributedStringRendered(firstChunkRendered)) {
            $0.attributedString = firstChunkRendered
            $0.scrollToBottomId += 1
        }
        
        // Send second chunk
        let secondChunk = "Second chunk "
        continuation.yield(secondChunk)
        await store.receive(.streamChunkReceived(secondChunk)) {
            $0.streamingResponse = firstChunk + secondChunk
        }
        
        let secondChunkRendered = await AttributedStringRenderer.renderMarkdown(firstChunk + secondChunk)
        await store.receive(.attributedStringRendered(secondChunkRendered)) {
            $0.attributedString = secondChunkRendered
            $0.scrollToBottomId += 1
        }
        
        // Send third chunk
        let thirdChunk = "Third chunk"
        continuation.yield(thirdChunk)
        await store.receive(.streamChunkReceived(thirdChunk)) {
            $0.streamingResponse = firstChunk + secondChunk + thirdChunk
        }
        
        let thirdChunkRendered = await AttributedStringRenderer.renderMarkdown(firstChunk + secondChunk + thirdChunk)
        await store.receive(.attributedStringRendered(thirdChunkRendered)) {
            $0.attributedString = thirdChunkRendered
            $0.scrollToBottomId += 1
        }
        
        // Complete the stream
        continuation.finish()
        await store.receive(.streamCompleted) {
            $0.isStreaming = false
        }
        
        // Verify saveToHistory was called and comparisonSaved is received
        await store.receive(.comparisonSaved(savedID)) {
            $0.comparisonID = savedID
        }
    }
    
    @Test
    func testStreamChunkReceived() async {
        let initialResponse = "Initial "
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            streamingResponse: initialResponse
        )) {
            ResponseDetailFeature()
        }
        
        let firstChunk = "chunk1 "
        await store.send(.streamChunkReceived(firstChunk)) {
            $0.streamingResponse = initialResponse + firstChunk
        }
        
        let firstChunkRendered = await AttributedStringRenderer.renderMarkdown(initialResponse + firstChunk)
        await store.receive(.attributedStringRendered(firstChunkRendered)) {
            $0.attributedString = firstChunkRendered
        }
        
        let secondChunk = "chunk2 "
        await store.send(.streamChunkReceived(secondChunk)) {
            $0.streamingResponse = initialResponse + firstChunk + secondChunk
        }
        
        let secondChunkRendered = await AttributedStringRenderer.renderMarkdown(initialResponse + firstChunk + secondChunk)
        await store.receive(.attributedStringRendered(secondChunkRendered)) {
            $0.attributedString = secondChunkRendered
        }
        
        let thirdChunk = "chunk3 "
        await store.send(.streamChunkReceived(thirdChunk)) {
            $0.streamingResponse = initialResponse + firstChunk + secondChunk + thirdChunk
        }
        
        let thirdChunkRendered = await AttributedStringRenderer.renderMarkdown(initialResponse + firstChunk + secondChunk + thirdChunk)
        await store.receive(.attributedStringRendered(thirdChunkRendered)) {
            $0.attributedString = thirdChunkRendered
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
                    return UUID()
                }
            )
        }
        
        await store.send(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
            $0.shouldStartStreaming = false
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
            $0.shouldStartStreaming = false
        }
        
        // Send a chunk
        continuation.yield("Test response")
        await store.receive(.streamChunkReceived("Test response")) {
            $0.streamingResponse = "Test response"
        }
        
        let rendered = await AttributedStringRenderer.renderMarkdown("Test response")
        await store.receive(.attributedStringRendered(rendered)) {
            $0.attributedString = rendered
            $0.scrollToBottomId += 1
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
        let savedID = UUID()
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
                    return savedID
                }
            )
        }
        
        await store.send(.startStreaming) {
            $0.isStreaming = true
            $0.errorMessage = nil
            $0.shouldStartStreaming = false
        }
        
        // Send chunks
        continuation.yield("Response ")
        await store.receive(.streamChunkReceived("Response ")) {
            $0.streamingResponse = "Response "
        }
        
        let firstRendered = await AttributedStringRenderer.renderMarkdown("Response ")
        await store.receive(.attributedStringRendered(firstRendered)) {
            $0.attributedString = firstRendered
            $0.scrollToBottomId += 1
        }
        
        continuation.yield("text")
        await store.receive(.streamChunkReceived("text")) {
            $0.streamingResponse = "Response text"
        }
        
        let secondRendered = await AttributedStringRenderer.renderMarkdown("Response text")
        await store.receive(.attributedStringRendered(secondRendered)) {
            $0.attributedString = secondRendered
            $0.scrollToBottomId += 1
        }
        
        // Complete the stream
        continuation.finish()
        await store.receive(.streamCompleted) {
            $0.isStreaming = false
        }
        
        // Verify save was called with correct parameters
        await store.receive(.comparisonSaved(savedID)) {
            $0.comparisonID = savedID
        }
        
        #expect(saveCalled == true)
        #expect(savedWord1 == "word1")
        #expect(savedWord2 == "word2")
        #expect(savedSentence == "This is a sentence")
        #expect(savedResponse == "Response text")
    }
    
    // MARK: - Share Functionality Test

    @Test
    func testGenerateAudioButtonTappedSuccess() async {
        let transcript = """
        Alex (Male): Here's the key difference.
        Mia (Female): Great, let's explain with examples.
        """
        let metadata = ComparisonAudioMetadata(
            relativePath: "ComparisonAudio/test.mp3",
            durationSeconds: 12.5,
            voiceID: "voice",
            model: "model",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let comparisonID = UUID()

        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            comparisonID: comparisonID,
            streamingResponse: "## Result",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonPodcastTranscript.generateTranscript = { markdown in
                #expect(markdown == "## Result")
                return transcript
            }
            $0.comparisonAudioService.generateAndAttach = { id, markdown in
                #expect(id == comparisonID)
                #expect(markdown == transcript)
                return metadata
            }
        }

        await store.send(.generateAudioButtonTapped) {
            $0.isGeneratingAudio = true
            $0.isGeneratingPodcastTranscript = true
            $0.audioGenerationProgress = 0.05
            $0.audioGenerationStatusMessage = "Generating podcast transcript..."
            $0.audioErrorMessage = nil
            $0.podcastTranscriptErrorMessage = nil
            $0.shouldAutoPlayAfterAudioReady = false
        }
        await store.receive(.audioGenerationProgressUpdated(0.2, "Generating podcast transcript...")) {
            $0.audioGenerationProgress = 0.2
            $0.audioGenerationStatusMessage = "Generating podcast transcript..."
        }
        await store.receive(.podcastTranscriptSucceeded(transcript)) {
            $0.isGeneratingPodcastTranscript = false
            $0.podcastTranscript = transcript
            $0.podcastTranscriptErrorMessage = nil
        }
        await store.receive(.audioGenerationProgressUpdated(0.6, "Generating audio...")) {
            $0.audioGenerationProgress = 0.6
            $0.audioGenerationStatusMessage = "Generating audio..."
        }
        await store.receive(.audioGenerationSucceeded(metadata)) {
            $0.isGeneratingAudio = false
            $0.audioGenerationProgress = 1
            $0.audioGenerationStatusMessage = "Completed"
            $0.audioRelativePath = metadata.relativePath
            $0.audioDurationSeconds = metadata.durationSeconds
            $0.shouldAutoPlayAfterAudioReady = true
        }
    }

    @Test
    func testGenerateAudioButtonTappedFailure() async {
        struct AudioError: Error, LocalizedError {
            var errorDescription: String? { "Audio generation failed" }
        }

        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            comparisonID: UUID(),
            streamingResponse: "## Result",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonPodcastTranscript.generateTranscript = { _ in
                "Alex (Male): Test\nMia (Female): Test"
            }
            $0.comparisonAudioService.generateAndAttach = { _, _ in
                throw AudioError()
            }
        }

        await store.send(.generateAudioButtonTapped) {
            $0.isGeneratingAudio = true
            $0.isGeneratingPodcastTranscript = true
            $0.audioGenerationProgress = 0.05
            $0.audioGenerationStatusMessage = "Generating podcast transcript..."
            $0.audioErrorMessage = nil
            $0.podcastTranscriptErrorMessage = nil
            $0.shouldAutoPlayAfterAudioReady = false
        }
        await store.receive(.audioGenerationProgressUpdated(0.2, "Generating podcast transcript...")) {
            $0.audioGenerationProgress = 0.2
            $0.audioGenerationStatusMessage = "Generating podcast transcript..."
        }
        await store.receive(.podcastTranscriptSucceeded("Alex (Male): Test\nMia (Female): Test")) {
            $0.isGeneratingPodcastTranscript = false
            $0.podcastTranscript = "Alex (Male): Test\nMia (Female): Test"
            $0.podcastTranscriptErrorMessage = nil
        }
        await store.receive(.audioGenerationProgressUpdated(0.6, "Generating audio...")) {
            $0.audioGenerationProgress = 0.6
            $0.audioGenerationStatusMessage = "Generating audio..."
        }
        await store.receive(.audioGenerationFailed("Audio generation failed")) {
            $0.isGeneratingAudio = false
            $0.audioGenerationProgress = 0
            $0.audioGenerationStatusMessage = nil
            $0.audioErrorMessage = "Audio generation failed"
        }
    }

    @Test
    func testGenerateAudioButtonTappedWithoutComparisonIDNoop() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            comparisonID: nil,
            streamingResponse: "## Result",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }

        await store.send(.generateAudioButtonTapped)
    }

    @Test
    func testGenerateAudioButtonTappedRegeneratesPodcastTranscript() async {
        let metadata = ComparisonAudioMetadata(
            relativePath: "ComparisonAudio/test.m4a",
            durationSeconds: 30,
            voiceID: "male+female",
            model: "eleven_multilingual_v2",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let comparisonID = UUID()
        let oldPodcastTranscript = """
        Alex (Male): First line.
        Mia (Female): Second line.
        """
        let newPodcastTranscript = """
        Alex (Male): Updated first line.
        Mia (Female): Updated second line.
        """

        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            comparisonID: comparisonID,
            streamingResponse: "## Result",
            shouldStartStreaming: false,
            podcastTranscript: oldPodcastTranscript
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonPodcastTranscript.generateTranscript = { markdown in
                #expect(markdown == "## Result")
                return newPodcastTranscript
            }
            $0.comparisonAudioService.generateAndAttach = { id, source in
                #expect(id == comparisonID)
                #expect(source == newPodcastTranscript)
                return metadata
            }
        }

        await store.send(.generateAudioButtonTapped) {
            $0.isGeneratingAudio = true
            $0.isGeneratingPodcastTranscript = true
            $0.audioGenerationProgress = 0.05
            $0.audioGenerationStatusMessage = "Generating podcast transcript..."
            $0.audioErrorMessage = nil
            $0.podcastTranscriptErrorMessage = nil
            $0.shouldAutoPlayAfterAudioReady = false
        }
        await store.receive(.audioGenerationProgressUpdated(0.2, "Generating podcast transcript...")) {
            $0.audioGenerationProgress = 0.2
            $0.audioGenerationStatusMessage = "Generating podcast transcript..."
        }
        await store.receive(.podcastTranscriptSucceeded(newPodcastTranscript)) {
            $0.isGeneratingPodcastTranscript = false
            $0.podcastTranscript = newPodcastTranscript
            $0.podcastTranscriptErrorMessage = nil
        }
        await store.receive(.audioGenerationProgressUpdated(0.6, "Generating audio...")) {
            $0.audioGenerationProgress = 0.6
            $0.audioGenerationStatusMessage = "Generating audio..."
        }
        await store.receive(.audioGenerationSucceeded(metadata)) {
            $0.isGeneratingAudio = false
            $0.audioGenerationProgress = 1
            $0.audioGenerationStatusMessage = "Completed"
            $0.audioRelativePath = metadata.relativePath
            $0.audioDurationSeconds = metadata.durationSeconds
            $0.shouldAutoPlayAfterAudioReady = true
        }
    }

    @Test
    func testOnAppearWithExistingGeneratedPodcastHydratesWithoutResettingPodcastState() async {
        let rendered = await AttributedStringRenderer.renderMarkdown("## Result")
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            comparisonID: UUID(),
            streamingResponse: "## Result",
            shouldStartStreaming: false,
            audioRelativePath: "ComparisonAudio/existing.m4a",
            audioDurationSeconds: 42.0,
            podcastTranscript: """
            Alex (Male): Existing podcast transcript.
            Mia (Female): Existing podcast transcript response.
            """
        )) {
            ResponseDetailFeature()
        }

        await store.send(.onAppear)
        await store.receive(.hydrateStoredResponse)
        await store.receive(.attributedStringRendered(rendered)) {
            $0.attributedString = rendered
        }

        #expect(store.state.audioRelativePath == "ComparisonAudio/existing.m4a")
        #expect(store.state.audioDurationSeconds == 42.0)
        #expect(store.state.podcastTranscript.contains("Alex (Male): Existing podcast transcript."))
        #expect(store.state.podcastTranscript.contains("Mia (Female): Existing podcast transcript response."))
    }

    @Test
    func testGenerateAudioButtonTappedTranscriptFailure() async {
        struct TranscriptError: Error, LocalizedError {
            var errorDescription: String? { "Podcast transcript failed" }
        }

        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            comparisonID: UUID(),
            streamingResponse: "## Result",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonPodcastTranscript.generateTranscript = { _ in
                throw TranscriptError()
            }
            $0.comparisonAudioService.generateAndAttach = { _, _ in
                #expect(Bool(false), "audio generation should not be called when transcript generation fails")
                return ComparisonAudioMetadata(
                    relativePath: "",
                    durationSeconds: 0,
                    voiceID: "",
                    model: "",
                    generatedAt: .distantPast
                )
            }
        }

        await store.send(.generateAudioButtonTapped) {
            $0.isGeneratingAudio = true
            $0.isGeneratingPodcastTranscript = true
            $0.audioGenerationProgress = 0.05
            $0.audioGenerationStatusMessage = "Generating podcast transcript..."
            $0.audioErrorMessage = nil
            $0.podcastTranscriptErrorMessage = nil
            $0.shouldAutoPlayAfterAudioReady = false
        }
        await store.receive(.audioGenerationProgressUpdated(0.2, "Generating podcast transcript...")) {
            $0.audioGenerationProgress = 0.2
            $0.audioGenerationStatusMessage = "Generating podcast transcript..."
        }
        await store.receive(.audioGenerationFailed("Podcast transcript failed")) {
            $0.isGeneratingAudio = false
            $0.isGeneratingPodcastTranscript = false
            $0.audioGenerationProgress = 0
            $0.audioGenerationStatusMessage = nil
            $0.audioErrorMessage = "Podcast transcript failed"
        }
    }

    @Test
    func testGeneratePodcastTranscriptButtonTappedSuccess() async {
        let transcript = """
        Alex (Male): Here's the key difference.
        Mia (Female): Great, let's explain with examples.
        """

        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: "## Result",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonPodcastTranscript.generateTranscript = { markdown in
                #expect(markdown == "## Result")
                return transcript
            }
        }

        await store.send(.generatePodcastTranscriptButtonTapped) {
            $0.isGeneratingPodcastTranscript = true
            $0.podcastTranscriptErrorMessage = nil
        }
        await store.receive(.podcastTranscriptSucceeded(transcript)) {
            $0.isGeneratingPodcastTranscript = false
            $0.podcastTranscript = transcript
            $0.podcastTranscriptErrorMessage = nil
        }
    }

    @Test
    func testGeneratePodcastTranscriptButtonTappedFailure() async {
        struct TranscriptError: Error, LocalizedError {
            var errorDescription: String? { "Transcript generation failed" }
        }

        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: "## Result",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonPodcastTranscript.generateTranscript = { _ in
                throw TranscriptError()
            }
        }

        await store.send(.generatePodcastTranscriptButtonTapped) {
            $0.isGeneratingPodcastTranscript = true
            $0.podcastTranscriptErrorMessage = nil
        }
        await store.receive(.podcastTranscriptFailed("Transcript generation failed")) {
            $0.isGeneratingPodcastTranscript = false
            $0.podcastTranscriptErrorMessage = "Transcript generation failed"
        }
    }

    @Test
    func testGeneratePodcastTranscriptButtonTappedWithoutResponseNoop() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: "",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }

        await store.send(.generatePodcastTranscriptButtonTapped)
    }

    @Test
    func testMarkdownDetailButtonTappedPresentsDestination() async {
        let attributed = AttributedString("Rendered")
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: "## Result",
            attributedString: attributed,
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }

        await store.send(.markdownDetailButtonTapped) {
            $0.markdownDetail =
                MarkdownDetailFeature.State(
                    markdown: "## Result",
                    attributedString: attributed
                )
        }
    }

    @Test
    func testMarkdownDetailButtonTappedWithoutResponseNoop() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: "   ",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }

        await store.send(.markdownDetailButtonTapped)
    }

    @Test
    func testStreamChunkReceivedUpdatesPresentedMarkdownDetail() async {
        let initialAttributed = AttributedString("Initial rendered")
        let initialMarkdown = "Initial markdown"
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: initialMarkdown,
            attributedString: initialAttributed,
            shouldStartStreaming: false,
            markdownDetail: MarkdownDetailFeature.State(
                markdown: initialMarkdown,
                attributedString: initialAttributed
            )
        )) {
            ResponseDetailFeature()
        }

        await store.send(.streamChunkReceived(" + chunk")) {
            $0.streamingResponse = "Initial markdown + chunk"
            $0.markdownDetail?.markdown = "Initial markdown + chunk"
        }

        let rendered = await AttributedStringRenderer.renderMarkdown("Initial markdown + chunk")
        await store.receive(.attributedStringRendered(rendered)) {
            $0.attributedString = rendered
            $0.markdownDetail?.attributedString = rendered
        }
    }

    @Test
    func testAudioGenerationProgressIsClamped() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }

        await store.send(.audioGenerationProgressUpdated(-1, "Start")) {
            $0.audioGenerationProgress = 0
            $0.audioGenerationStatusMessage = "Start"
        }
        await store.send(.audioGenerationProgressUpdated(2, "End")) {
            $0.audioGenerationProgress = 1
            $0.audioGenerationStatusMessage = "End"
        }
    }

    @Test
    func testGenerateAudioButtonTappedWithoutResponseNoop() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            comparisonID: UUID(),
            streamingResponse: "   ",
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }

        await store.send(.generateAudioButtonTapped)
    }

    @Test
    func testGenerateAudioButtonTappedWhileGeneratingNoop() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            comparisonID: UUID(),
            streamingResponse: "## Result",
            shouldStartStreaming: false,
            isGeneratingAudio: true
        )) {
            ResponseDetailFeature()
        }

        await store.send(.generateAudioButtonTapped)
    }

    @Test
    func testGeneratePodcastTranscriptButtonTappedWhileGeneratingNoop() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: "## Result",
            shouldStartStreaming: false,
            isGeneratingPodcastTranscript: true
        )) {
            ResponseDetailFeature()
        }

        await store.send(.generatePodcastTranscriptButtonTapped)
    }

    @Test
    func testAudioPlaybackActionsDisableAutoPlay() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            shouldStartStreaming: false,
            shouldAutoPlayAfterAudioReady: true
        )) {
            ResponseDetailFeature()
        }

        await store.send(.audioPlaybackToggled) {
            $0.shouldAutoPlayAfterAudioReady = false
        }
        await store.send(.audioPlaybackStopped)
    }

    @Test
    func testDismissMarkdownDetailDestination() async {
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: "## Result",
            shouldStartStreaming: false,
            markdownDetail: MarkdownDetailFeature.State(
                markdown: "## Result",
                attributedString: AttributedString("Result")
            )
        )) {
            ResponseDetailFeature()
        }

        await store.send(.markdownDetail(.dismiss)) {
            $0.markdownDetail = nil
        }
    }

    @Test
    func testMarkdownDetailCanReopenAfterDismiss() async {
        let rendered = AttributedString("Rendered")
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            streamingResponse: "## Result",
            attributedString: rendered,
            shouldStartStreaming: false
        )) {
            ResponseDetailFeature()
        }

        await store.send(.markdownDetailButtonTapped) {
            $0.markdownDetail = MarkdownDetailFeature.State(
                markdown: "## Result",
                attributedString: rendered
            )
        }
        await store.send(.markdownDetail(.dismiss)) {
            $0.markdownDetail = nil
        }
        await store.send(.markdownDetailButtonTapped) {
            $0.markdownDetail = MarkdownDetailFeature.State(
                markdown: "## Result",
                attributedString: rendered
            )
        }
    }

    @Test
    func testShareButtonTapped() async {
        var capturedShareText: String?
        
        let store = TestStore(initialState: ResponseDetailFeature.State(
            word1: "character",
            word2: "characteristic",
            sentence: "This is a test sentence",
            streamingResponse: "This is the analysis response"
        )) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.platformShare.share = { text in
                capturedShareText = text
            }
        }
        
        await store.send(.shareButtonTapped)

        #expect(capturedShareText?.contains("Word Comparison: character vs characteristic") == true)
        #expect(capturedShareText?.contains("Context: This is a test sentence") == true)
        #expect(capturedShareText?.contains("This is the analysis response") == true)
    }
}
