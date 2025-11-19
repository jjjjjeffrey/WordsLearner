//
//  ComparisonHistory.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import Foundation
import SQLiteData

@Table
struct ComparisonHistory: Identifiable, Codable, Equatable {
    let id: UUID
    let word1: String
    let word2: String
    let sentence: String
    let response: String
    let date: Date
}
