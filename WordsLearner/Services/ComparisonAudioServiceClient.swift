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
}

private struct PodcastAudioSegment: Sendable {
    var text: String
    var voiceID: String
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
                let podcastSegments = parsePodcastSegments(sourceText)

                let audioData: Data
                let fileExtension: String
                let voiceID: String
                let modelID = ComparisonAudioGeneratorClient.defaultModelID

                if podcastSegments.isEmpty {
                    let narrationText = formatter.makeNarrationText(markdown)
                    audioData = try await generator.generateAudio(narrationText)
                    fileExtension = "mp3"
                    voiceID = ComparisonAudioGeneratorClient.defaultVoiceID
                } else {
                    var segmentFiles: [URL] = []
                    defer {
                        for url in segmentFiles {
                            try? FileManager.default.removeItem(at: url)
                        }
                    }

                    for segment in podcastSegments {
                        let segmentAudio = try await elevenLabsAudioGenerator.generateAudio(
                            segment.text,
                            segment.voiceID,
                            modelID
                        )
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
                    generatedAt: now
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
                    generatedAt: Date()
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

private func parsePodcastSegments(_ transcript: String) -> [PodcastAudioSegment] {
    var segments: [PodcastAudioSegment] = []
    var current: PodcastAudioSegment?

    for rawLine in transcript.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
        let line = String(rawLine).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !line.isEmpty else { continue }

        if line.hasPrefix("Alex (Male):") {
            if let current {
                segments.append(current)
            }
            let text = line.replacingOccurrences(of: "Alex (Male):", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            current = .init(text: text, voiceID: ComparisonAudioServiceClient.podcastMaleVoiceID)
            continue
        }

        if line.hasPrefix("Mia (Female):") {
            if let current {
                segments.append(current)
            }
            let text = line.replacingOccurrences(of: "Mia (Female):", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            current = .init(text: text, voiceID: ComparisonAudioServiceClient.podcastFemaleVoiceID)
            continue
        }

        if var updatedCurrent = current {
            updatedCurrent.text += " " + line
            current = updatedCurrent
        }
    }

    if let current {
        segments.append(current)
    }

    return segments.filter { !$0.text.isEmpty }
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
