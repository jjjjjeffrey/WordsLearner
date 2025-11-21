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
}

extension ComparisonHistory.Draft: Identifiable {}
