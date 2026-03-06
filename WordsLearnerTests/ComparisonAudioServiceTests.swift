//
//  ComparisonAudioServiceTests.swift
//  WordsLearnerTests
//

import DependenciesTestSupport
import Dependencies
import Foundation
import Testing

@testable import WordsLearner

@MainActor
struct ComparisonAudioServiceTests {
    @Test
    func narrationFormatterStripsMarkdownSyntax() {
        let markdown = """
        ## Heading
        **bold** text and [link](https://example.com)
        - bullet one
        1. numbered
        """

        let text = ComparisonNarrationFormatterClient.liveValue.makeNarrationText(markdown)

        #expect(!text.contains("##"))
        #expect(!text.contains("**"))
        #expect(!text.contains("["))
        #expect(text.contains("Heading"))
        #expect(text.contains("bold text"))
        #expect(text.contains("bullet one"))
        #expect(text.contains("numbered"))
    }

    @Test
    func comparisonAudioServiceGenerateAndAttachSuccess() async throws {
        let comparisonID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        try await withDependencies {
            try! $0.bootstrapDatabase(useTest: true, seed: { db in
                try db.seed {
                    ComparisonHistory.Draft(
                        id: comparisonID,
                        word1: "affect",
                        word2: "effect",
                        sentence: "The policy will affect the final effect.",
                        response: "Response",
                        date: now,
                        isRead: false
                    )
                }
            })
            $0.comparisonNarrationFormatter.makeNarrationText = { _ in "Narration text" }
            $0.comparisonAudioGenerator.generateAudio = { _ in Data("fake-audio".utf8) }
            $0.comparisonAudioAssetStore.writeAudio = { _, id, _ in
                #expect(id == comparisonID)
                return "ComparisonAudio/\(id.uuidString).mp3"
            }
            $0.date.now = now
            $0.comparisonAudioService = .liveValue
        } operation: {
            @Dependency(\.comparisonAudioService) var audioService
            @Dependency(\.defaultDatabase) var database

            let metadata = try await audioService.generateAndAttach(comparisonID, "## Markdown")
            #expect(metadata.relativePath == "ComparisonAudio/\(comparisonID.uuidString).mp3")
            #expect(metadata.voiceID == ComparisonAudioGeneratorClient.defaultVoiceID)
            #expect(metadata.model == ComparisonAudioGeneratorClient.defaultModelID)
            #expect(metadata.generatedAt == now)
            #expect(metadata.transcriptTurnTimings.isEmpty)

            let saved = try await database.read { db in
                try ComparisonHistory
                    .fetchAll(db)
                    .first(where: { $0.id == comparisonID })
            }

            #expect(saved?.audioRelativePath == metadata.relativePath)
            #expect(saved?.podcastTranscript == "## Markdown")
            #expect(saved?.audioFileExtension == "mp3")
            #expect(saved?.audioData == Data("fake-audio".utf8))
            #expect(saved?.audioVoiceID == metadata.voiceID)
            #expect(saved?.audioModel == metadata.model)
            #expect(saved?.audioGeneratedAt == metadata.generatedAt)
            #expect(saved?.audioTranscriptTimingData == nil)
        }
    }

    @Test
    func comparisonAudioServiceDoesNotUpdateRecordOnGeneratorFailure() async throws {
        struct AudioFailure: Error {}
        let comparisonID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        try await withDependencies {
            try! $0.bootstrapDatabase(useTest: true, seed: { db in
                try db.seed {
                    ComparisonHistory.Draft(
                        id: comparisonID,
                        word1: "affect",
                        word2: "effect",
                        sentence: "The policy will affect the final effect.",
                        response: "Response",
                        date: now,
                        isRead: false
                    )
                }
            })
            $0.comparisonNarrationFormatter.makeNarrationText = { _ in "Narration text" }
            $0.comparisonAudioGenerator.generateAudio = { _ in throw AudioFailure() }
            $0.comparisonAudioAssetStore.writeAudio = { _, _, _ in "" }
            $0.comparisonAudioService = .liveValue
        } operation: {
            @Dependency(\.comparisonAudioService) var audioService
            @Dependency(\.defaultDatabase) var database

            await #expect(throws: AudioFailure.self) {
                _ = try await audioService.generateAndAttach(comparisonID, "## Markdown")
            }

            let saved = try await database.read { db in
                try ComparisonHistory
                    .fetchAll(db)
                    .first(where: { $0.id == comparisonID })
            }
            #expect(saved?.audioRelativePath == nil)
            #expect(saved?.podcastTranscript == nil)
            #expect(saved?.audioFileExtension == nil)
            #expect(saved?.audioData == nil)
            #expect(saved?.audioDurationSeconds == nil)
            #expect(saved?.audioGeneratedAt == nil)
            #expect(saved?.audioVoiceID == nil)
            #expect(saved?.audioModel == nil)
            #expect(saved?.audioTranscriptTimingData == nil)
        }
    }

    @Test
    func comparisonAudioServiceUsesPodcastVoicesWhenTranscriptIsDialog() async throws {
        let comparisonID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let transcript = """
        Alex (Male): First teaching point.
        More details on same speaker line.
        """
        let segmentAudio = Data("segment-audio".utf8)

        try await withDependencies {
            try! $0.bootstrapDatabase(useTest: true, seed: { db in
                try db.seed {
                    ComparisonHistory.Draft(
                        id: comparisonID,
                        word1: "affect",
                        word2: "effect",
                        sentence: "The policy will affect the final effect.",
                        response: "Response",
                        date: now,
                        isRead: false
                    )
                }
            })
            $0.comparisonNarrationFormatter.makeNarrationText = { _ in
                #expect(Bool(false), "narration formatter should not be used for podcast transcript input")
                return ""
            }
            $0.comparisonAudioGenerator.generateAudio = { _ in
                #expect(Bool(false), "comparison audio generator should not be used for podcast transcript input")
                return Data()
            }
            $0.elevenLabsAudioGenerator.generateAudio = { text, voiceID, modelID in
                #expect(text == "First teaching point. More details on same speaker line.")
                #expect(voiceID == ComparisonAudioServiceClient.podcastMaleVoiceID)
                #expect(modelID == ComparisonAudioGeneratorClient.defaultModelID)
                return segmentAudio
            }
            $0.comparisonAudioAssetStore.writeAudio = { data, id, fileExtension in
                #expect(data == segmentAudio)
                #expect(id == comparisonID)
                #expect(fileExtension == "mp3")
                return "ComparisonAudio/\(id.uuidString).mp3"
            }
            $0.date.now = now
            $0.comparisonAudioService = .liveValue
        } operation: {
            @Dependency(\.comparisonAudioService) var audioService
            @Dependency(\.defaultDatabase) var database

            let metadata = try await audioService.generateAndAttach(comparisonID, transcript)
            #expect(metadata.relativePath == "ComparisonAudio/\(comparisonID.uuidString).mp3")
            #expect(
                metadata.voiceID
                    == "\(ComparisonAudioServiceClient.podcastMaleVoiceID)+\(ComparisonAudioServiceClient.podcastFemaleVoiceID)"
            )
            #expect(metadata.model == ComparisonAudioGeneratorClient.defaultModelID)
            #expect(metadata.generatedAt == now)
            #expect(metadata.transcriptTurnTimings.count == 1)
            #expect(metadata.transcriptTurnTimings.first?.speaker == PodcastTranscriptParser.alexSpeaker)
            #expect(metadata.transcriptTurnTimings.first?.text == "First teaching point. More details on same speaker line.")

            let saved = try await database.read { db in
                try ComparisonHistory
                    .fetchAll(db)
                    .first(where: { $0.id == comparisonID })
            }
            #expect(saved?.podcastTranscript == transcript)
            #expect(saved?.audioFileExtension == "mp3")
            #expect(saved?.audioData == segmentAudio)
            #expect(saved?.audioVoiceID == metadata.voiceID)
            #expect(saved?.audioModel == metadata.model)
            #expect(PodcastTranscriptTimingCodec.decode(saved?.audioTranscriptTimingData).count == 1)
        }
    }

    @Test
    func comparisonAudioServiceUsesFemalePodcastVoiceWhenTranscriptStartsWithMia() async throws {
        let comparisonID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let transcript = """
        Mia (Female): Let's start with the effect in context.
        """
        let segmentAudio = Data("female-segment-audio".utf8)

        try await withDependencies {
            try! $0.bootstrapDatabase(useTest: true, seed: { db in
                try db.seed {
                    ComparisonHistory.Draft(
                        id: comparisonID,
                        word1: "affect",
                        word2: "effect",
                        sentence: "The policy will affect the final effect.",
                        response: "Response",
                        date: now,
                        isRead: false
                    )
                }
            })
            $0.comparisonNarrationFormatter.makeNarrationText = { _ in
                #expect(Bool(false), "narration formatter should not be used for podcast transcript input")
                return ""
            }
            $0.comparisonAudioGenerator.generateAudio = { _ in
                #expect(Bool(false), "comparison audio generator should not be used for podcast transcript input")
                return Data()
            }
            $0.elevenLabsAudioGenerator.generateAudio = { text, voiceID, modelID in
                #expect(text == "Let's start with the effect in context.")
                #expect(voiceID == ComparisonAudioServiceClient.podcastFemaleVoiceID)
                #expect(modelID == ComparisonAudioGeneratorClient.defaultModelID)
                return segmentAudio
            }
            $0.comparisonAudioAssetStore.writeAudio = { data, id, fileExtension in
                #expect(data == segmentAudio)
                #expect(id == comparisonID)
                #expect(fileExtension == "mp3")
                return "ComparisonAudio/\(id.uuidString).mp3"
            }
            $0.date.now = now
            $0.comparisonAudioService = .liveValue
        } operation: {
            @Dependency(\.comparisonAudioService) var audioService
            @Dependency(\.defaultDatabase) var database

            let metadata = try await audioService.generateAndAttach(comparisonID, transcript)
            #expect(metadata.relativePath == "ComparisonAudio/\(comparisonID.uuidString).mp3")
            #expect(
                metadata.voiceID
                    == "\(ComparisonAudioServiceClient.podcastMaleVoiceID)+\(ComparisonAudioServiceClient.podcastFemaleVoiceID)"
            )
            #expect(metadata.model == ComparisonAudioGeneratorClient.defaultModelID)
            #expect(metadata.generatedAt == now)
            #expect(metadata.transcriptTurnTimings.count == 1)
            #expect(metadata.transcriptTurnTimings.first?.speaker == PodcastTranscriptParser.miaSpeaker)
            #expect(metadata.transcriptTurnTimings.first?.text == "Let's start with the effect in context.")

            let saved = try await database.read { db in
                try ComparisonHistory
                    .fetchAll(db)
                    .first(where: { $0.id == comparisonID })
            }
            #expect(saved?.podcastTranscript == transcript)
            #expect(saved?.audioFileExtension == "mp3")
            #expect(saved?.audioData == segmentAudio)
            #expect(saved?.audioVoiceID == metadata.voiceID)
            #expect(saved?.audioModel == metadata.model)
            #expect(PodcastTranscriptTimingCodec.decode(saved?.audioTranscriptTimingData).count == 1)
        }
    }
}
