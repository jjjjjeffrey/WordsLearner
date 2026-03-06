//
//  PodcastTranscriptTurnTiming.swift
//  WordsLearner
//

import Foundation

struct PodcastTranscriptTurnTiming: Codable, Equatable, Sendable {
    var speaker: String
    var text: String
    var startSeconds: Double
    var endSeconds: Double

    var displayText: String {
        "\(speaker): \(text)"
    }

    func contains(timeSeconds: Double) -> Bool {
        timeSeconds >= startSeconds && timeSeconds < endSeconds
    }
}

struct PodcastTranscriptTurn: Equatable, Sendable {
    var speaker: String
    var text: String
    var voiceID: String
}

enum PodcastTranscriptTimingCodec {
    static func decode(_ json: String?) -> [PodcastTranscriptTurnTiming] {
        guard
            let json,
            let data = json.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([PodcastTranscriptTurnTiming].self, from: data)
        else {
            return []
        }
        return decoded
    }

    static func encode(_ timings: [PodcastTranscriptTurnTiming]) -> String? {
        guard
            !timings.isEmpty,
            let data = try? JSONEncoder().encode(timings),
            let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return json
    }
}

enum PodcastTranscriptParser {
    static let alexPrefix = "Alex (Male):"
    static let miaPrefix = "Mia (Female):"
    static let alexSpeaker = "Alex (Male)"
    static let miaSpeaker = "Mia (Female)"

    static func parseTurns(
        from transcript: String,
        maleVoiceID: String,
        femaleVoiceID: String
    ) -> [PodcastTranscriptTurn] {
        var turns: [PodcastTranscriptTurn] = []
        var current: PodcastTranscriptTurn?

        for rawLine in transcript.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix(alexPrefix) {
                if let current {
                    turns.append(current)
                }
                let text = line.replacingOccurrences(of: alexPrefix, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                current = .init(speaker: alexSpeaker, text: text, voiceID: maleVoiceID)
                continue
            }

            if line.hasPrefix(miaPrefix) {
                if let current {
                    turns.append(current)
                }
                let text = line.replacingOccurrences(of: miaPrefix, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                current = .init(speaker: miaSpeaker, text: text, voiceID: femaleVoiceID)
                continue
            }

            if var updatedCurrent = current {
                updatedCurrent.text += " " + line
                current = updatedCurrent
            }
        }

        if let current {
            turns.append(current)
        }

        return turns.filter { !$0.text.isEmpty }
    }
}
