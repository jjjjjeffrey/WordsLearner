//
//  ComparisonAudioAssetStoreClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation
import SQLiteData

@DependencyClient
struct ComparisonAudioAssetStoreClient: Sendable {
    var writeAudio: @Sendable (_ data: Data, _ comparisonID: UUID, _ fileExtension: String) throws -> String
    var loadAudioData: @Sendable (_ relativePath: String) throws -> Data?
}

extension ComparisonAudioAssetStoreClient: DependencyKey {
    static let rootFolder = "ComparisonAudio"

    static var liveValue: Self {
        @Dependency(\.defaultDatabase) var database
        return Self(
            writeAudio: { _, comparisonID, fileExtension in
                let filename = "\(comparisonID.uuidString).\(fileExtension)"
                return "\(rootFolder)/\(filename)"
            },
            loadAudioData: { relativePath in
                guard let comparisonID = parseComparisonID(from: relativePath) else {
                    return nil
                }
                let record = try database.read { db in
                    try ComparisonHistory
                        .where { $0.id == comparisonID }
                        .fetchOne(db)
                }
                guard let data = record?.audioData, !data.isEmpty else { return nil }
                return data
            }
        )
    }

    static var previewValue: Self { liveValue }
    static var testValue: Self { liveValue }
}

extension DependencyValues {
    var comparisonAudioAssetStore: ComparisonAudioAssetStoreClient {
        get { self[ComparisonAudioAssetStoreClient.self] }
        set { self[ComparisonAudioAssetStoreClient.self] = newValue }
    }
}

private func parseComparisonID(from relativePath: String) -> UUID? {
    let filename = URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
    return UUID(uuidString: filename)
}
