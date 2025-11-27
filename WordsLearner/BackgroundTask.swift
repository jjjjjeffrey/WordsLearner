//
//  BackgroundTask.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/26/25.
//

import Foundation
import SQLiteData

@Table
nonisolated struct BackgroundTask: Identifiable, Equatable {
    let id: UUID
    var word1: String
    var word2: String
    var sentence: String
    var status: String  // "pending", "generating", "completed", "failed"
    var response: String
    var error: String?
    var createdAt: Date
    var updatedAt: Date
    
    enum Status: String, Equatable {
        case pending
        case generating
        case completed
        case failed
    }
    
    var taskStatus: Status {
        Status(rawValue: status) ?? .pending
    }
}

extension BackgroundTask.Draft: Identifiable {}

// Helper extensions
extension BackgroundTask {
    static func create(
        word1: String,
        word2: String,
        sentence: String,
        now: Date = Date()
    ) -> Draft {
        Draft(
            id: UUID(),
            word1: word1,
            word2: word2,
            sentence: sentence,
            status: Status.pending.rawValue,
            response: "",
            error: nil,
            createdAt: now,
            updatedAt: now
        )
    }
    
    func updating(status: Status, error: String? = nil) -> Draft {
        Draft(
            id: id,
            word1: word1,
            word2: word2,
            sentence: sentence,
            status: status.rawValue,
            response: response,
            error: error,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func updating(response: String, status: Status) -> Draft {
        Draft(
            id: id,
            word1: word1,
            word2: word2,
            sentence: sentence,
            status: status.rawValue,
            response: response,
            error: error,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

