//
//  MultimodalLesson.swift
//  WordsLearner
//

import Foundation
import SQLiteData

@Table
nonisolated struct MultimodalLesson: Identifiable, Equatable {
    let id: UUID
    var word1: String
    var word2: String
    var userSentence: String
    var status: String
    var storyboardJSON: String
    var stylePreset: String
    var voicePreset: String
    var imageModel: String
    var audioModel: String
    var generatorVersion: String
    var claritySelfRating: Int?
    var lessonDurationSeconds: Double?
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    enum Status: String, Equatable {
        case generating
        case ready
        case failed
    }

    var lessonStatus: Status {
        Status(rawValue: status) ?? .failed
    }
}

extension MultimodalLesson.Draft: Identifiable {}
