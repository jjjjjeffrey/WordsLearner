//
//  ComparisonHistoryTransfer.swift
//  WordsLearner
//
//  Created by Cursor on 1/25/26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ComparisonHistoryExportRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let word1: String
    let word2: String
    let sentence: String
    let response: String
    let date: Date
    let isRead: Bool
    
    init(from history: ComparisonHistory) {
        id = history.id
        word1 = history.word1
        word2 = history.word2
        sentence = history.sentence
        response = history.response
        date = history.date
        isRead = history.isRead
    }
    
    func toDraft() -> ComparisonHistory.Draft {
        ComparisonHistory.Draft(
            id: id,
            word1: word1,
            word2: word2,
            sentence: sentence,
            response: response,
            date: date,
            isRead: isRead
        )
    }
}

struct ComparisonHistoryExportDocument: FileDocument, Equatable {
    static var readableContentTypes: [UTType] { [.json] }
    
    var records: [ComparisonHistoryExportRecord]
    
    init(records: [ComparisonHistoryExportRecord]) {
        self.records = records
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            records = []
            return
        }
        records = try Self.decoder.decode([ComparisonHistoryExportRecord].self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Self.encoder.encode(records)
        return FileWrapper(regularFileWithContents: data)
    }
    
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    static func == (lhs: ComparisonHistoryExportDocument, rhs: ComparisonHistoryExportDocument) -> Bool {
        lhs.records == rhs.records
    }
}
