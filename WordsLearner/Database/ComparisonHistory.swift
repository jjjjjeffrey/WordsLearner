//
//  ComparisonHistory.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import Foundation
import SQLiteData

@Table
nonisolated struct ComparisonHistory: Identifiable, Equatable {
    let id: UUID
    var word1: String
    var word2: String
    var sentence: String
    var response: String
    var date: Date
    var isRead: Bool
    var audioRelativePath: String? = nil
    var podcastTranscript: String? = nil
    var audioFileExtension: String? = nil
    var audioData: Data? = nil
    var audioDurationSeconds: Double? = nil
    var audioGeneratedAt: Date? = nil
    var audioVoiceID: String? = nil
    var audioModel: String? = nil
    var audioTranscriptTimingData: String? = nil
}

extension ComparisonHistory.Draft: Identifiable {}
