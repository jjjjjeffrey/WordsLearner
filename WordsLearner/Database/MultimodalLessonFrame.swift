//
//  MultimodalLessonFrame.swift
//  WordsLearner
//

import Foundation
import SQLiteData

@Table
nonisolated struct MultimodalLessonFrame: Identifiable, Equatable {
    let id: UUID
    var lessonID: UUID
    var frameIndex: Int
    var frameRole: String
    var title: String
    var caption: String
    var narrationText: String
    var imagePrompt: String
    var imageRelativePath: String
    var audioRelativePath: String
    var audioDurationSeconds: Double?
    var checkPrompt: String?
    var expectedAnswer: String?
    var createdAt: Date
    var updatedAt: Date
}

extension MultimodalLessonFrame.Draft: Identifiable {}
