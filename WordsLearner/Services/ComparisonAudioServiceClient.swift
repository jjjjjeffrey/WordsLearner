//
//  ComparisonAudioServiceClient.swift
//  WordsLearner
//

import AVFoundation
import ComposableArchitecture
import Foundation
import SQLiteData

struct ComparisonAudioMetadata: Equatable, Sendable {
    var relativePath: String
    var durationSeconds: Double
    var voiceID: String
    var model: String
    var generatedAt: Date
    var transcriptTurnTimings: [PodcastTranscriptTurnTiming] = []
}

enum ComparisonAudioServiceError: LocalizedError {
    case exportFailed
    case missingExportSession
    case missingInputAudioTrack

    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Failed to render podcast audio."
        case .missingExportSession:
            return "Failed to create audio export session."
        case .missingInputAudioTrack:
            return "Generated podcast segment has no audio track."
        }
    }
}

@DependencyClient
struct ComparisonAudioServiceClient: Sendable {
    var generateAndAttach: @Sendable (_ comparisonID: UUID, _ markdown: String) async throws -> ComparisonAudioMetadata
}

extension ComparisonAudioServiceClient: DependencyKey {
    static let podcastMaleVoiceID = "pNInz6obpgDQGcFmaJgB"
    static let podcastFemaleVoiceID = "21m00Tcm4TlvDq8ikWAM"

    static var liveValue: Self {
        @Dependency(\.comparisonNarrationFormatter) var formatter
        @Dependency(\.comparisonAudioGenerator) var generator
        @Dependency(\.elevenLabsAudioGenerator) var elevenLabsAudioGenerator
        @Dependency(\.comparisonAudioAssetStore) var assetStore
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now

        return Self(
            generateAndAttach: { comparisonID, markdown in
                let sourceText = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
                let podcastTurns = PodcastTranscriptParser.parseTurns(
                    from: sourceText,
                    maleVoiceID: Self.podcastMaleVoiceID,
                    femaleVoiceID: Self.podcastFemaleVoiceID
                )

                let audioData: Data
                let fileExtension: String
                let voiceID: String
                var transcriptTurnTimings: [PodcastTranscriptTurnTiming]
                let modelID = ComparisonAudioGeneratorClient.defaultModelID

                if podcastTurns.isEmpty {
                    let narrationText = formatter.makeNarrationText(markdown)
                    audioData = try await generator.generateAudio(narrationText)
                    fileExtension = "mp3"
                    voiceID = ComparisonAudioGeneratorClient.defaultVoiceID
                    transcriptTurnTimings = []
                } else {
                    var segmentFiles: [URL] = []
                    var segmentDurations: [Double] = []
                    defer {
                        for url in segmentFiles {
                            try? FileManager.default.removeItem(at: url)
                        }
                    }

                    for turn in podcastTurns {
                        let segmentAudio = try await elevenLabsAudioGenerator.generateAudio(
                            turn.text,
                            turn.voiceID,
                            modelID
                        )
                        let segmentDuration = (try? AVAudioPlayer(data: segmentAudio).duration) ?? 0
                        segmentDurations.append(max(0, segmentDuration))
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("mp3")
                        try segmentAudio.write(to: tempURL, options: .atomic)
                        segmentFiles.append(tempURL)
                    }

                    if segmentFiles.count == 1 {
                        audioData = try Data(contentsOf: segmentFiles[0])
                        fileExtension = "mp3"
                    } else {
                        audioData = try await mergeAudioFilesAsM4A(segmentFiles)
                        fileExtension = "m4a"
                    }
                    voiceID = "\(Self.podcastMaleVoiceID)+\(Self.podcastFemaleVoiceID)"
                    transcriptTurnTimings = makeTranscriptTurnTimings(
                        from: podcastTurns,
                        segmentDurations: segmentDurations
                    )
                }

                let relativePath = try assetStore.writeAudio(audioData, comparisonID, fileExtension)
                let duration: Double
                do {
                    duration = try AVAudioPlayer(data: audioData).duration
                } catch {
                    duration = 0
                }
                let metadata = ComparisonAudioMetadata(
                    relativePath: relativePath,
                    durationSeconds: duration,
                    voiceID: voiceID,
                    model: modelID,
                    generatedAt: now,
                    transcriptTurnTimings: transcriptTurnTimings
                )

                try await database.write { db in
                    try ComparisonHistory
                        .where { $0.id == comparisonID }
                        .update {
                            $0.audioRelativePath = metadata.relativePath
                            $0.podcastTranscript = sourceText
                            $0.audioFileExtension = fileExtension
                            $0.audioData = audioData
                            $0.audioDurationSeconds = metadata.durationSeconds
                            $0.audioGeneratedAt = metadata.generatedAt
                            $0.audioVoiceID = metadata.voiceID
                            $0.audioModel = metadata.model
                            $0.audioTranscriptTimingData = PodcastTranscriptTimingCodec.encode(metadata.transcriptTurnTimings)
                        }
                        .execute(db)
                }
                return metadata
            }
        )
    }

    static var previewValue: Self {
        Self(
            generateAndAttach: { _, _ in
                ComparisonAudioMetadata(
                    relativePath: "",
                    durationSeconds: 0,
                    voiceID: ComparisonAudioGeneratorClient.defaultVoiceID,
                    model: ComparisonAudioGeneratorClient.defaultModelID,
                    generatedAt: Date(),
                    transcriptTurnTimings: []
                )
            }
        )
    }

    static var testValue: Self { previewValue }
}

extension DependencyValues {
    var comparisonAudioService: ComparisonAudioServiceClient {
        get { self[ComparisonAudioServiceClient.self] }
        set { self[ComparisonAudioServiceClient.self] = newValue }
    }
}

private func makeTranscriptTurnTimings(
    from turns: [PodcastTranscriptTurn],
    segmentDurations: [Double]
) -> [PodcastTranscriptTurnTiming] {
    guard turns.count == segmentDurations.count else { return [] }

    var cursor: Double = 0
    return zip(turns, segmentDurations).map { turn, rawDuration in
        let duration = max(0, rawDuration)
        let timing = PodcastTranscriptTurnTiming(
            speaker: turn.speaker,
            text: turn.text,
            startSeconds: cursor,
            endSeconds: cursor + duration
        )
        cursor += duration
        return timing
    }
}

private func mergeAudioFilesAsM4A(_ inputFiles: [URL]) async throws -> Data {
    let composition = AVMutableComposition()
    guard
        let destinationTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
    else {
        throw ComparisonAudioServiceError.exportFailed
    }

    var cursor = CMTime.zero
    for url in inputFiles {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let sourceTrack = tracks.first else {
            throw ComparisonAudioServiceError.missingInputAudioTrack
        }
        let duration = try await asset.load(.duration)
        try destinationTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: sourceTrack,
            at: cursor
        )
        cursor = cursor + duration
    }

    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("m4a")
    try? FileManager.default.removeItem(at: outputURL)
    defer { try? FileManager.default.removeItem(at: outputURL) }

    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
        throw ComparisonAudioServiceError.missingExportSession
    }
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a

    try await exportSession.exportAsync()
    return try Data(contentsOf: outputURL)
}

private extension AVAssetExportSession {
    func exportAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportAsynchronously {
                if let error = self.error {
                    continuation.resume(throwing: error)
                    return
                }
                guard self.status == .completed else {
                    continuation.resume(throwing: ComparisonAudioServiceError.exportFailed)
                    return
                }
                continuation.resume()
            }
        }
    }
}
