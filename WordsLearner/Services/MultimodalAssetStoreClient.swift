//
//  MultimodalAssetStoreClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct MultimodalAssetStoreClient: Sendable {
    var lessonDirectory: @Sendable (UUID) throws -> URL
    var writeImage: @Sendable (_ data: Data, _ lessonID: UUID, _ frameIndex: Int) throws -> String
    var writeAudio: @Sendable (_ data: Data, _ lessonID: UUID, _ frameIndex: Int) throws -> String
    var resolve: @Sendable (_ relativePath: String) throws -> URL
}

extension MultimodalAssetStoreClient: DependencyKey {
    static let rootFolder = "MultimodalLessons"

    static var liveValue: Self {
        Self(
            lessonDirectory: { lessonID in
                let root = try baseURL()
                let dir = root.appendingPathComponent(rootFolder).appendingPathComponent(lessonID.uuidString)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            },
            writeImage: { data, lessonID, frameIndex in
                let dir = try liveValue.lessonDirectory(lessonID)
                let filename = "frame-\(frameIndex).png"
                let fileURL = dir.appendingPathComponent(filename)
                try data.write(to: fileURL, options: .atomic)
                return "\(rootFolder)/\(lessonID.uuidString)/\(filename)"
            },
            writeAudio: { data, lessonID, frameIndex in
                let dir = try liveValue.lessonDirectory(lessonID)
                let filename = "frame-\(frameIndex).mp3"
                let fileURL = dir.appendingPathComponent(filename)
                try data.write(to: fileURL, options: .atomic)
                return "\(rootFolder)/\(lessonID.uuidString)/\(filename)"
            },
            resolve: { relativePath in
                try baseURL().appendingPathComponent(relativePath)
            }
        )
    }

    static var previewValue: Self {
        liveValue
    }

    static var testValue: Self {
        liveValue
    }
}

private func baseURL() throws -> URL {
    guard
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
    else {
        throw AIError.invalidURL
    }
    try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
    return appSupport
}

extension DependencyValues {
    var multimodalAssetStore: MultimodalAssetStoreClient {
        get { self[MultimodalAssetStoreClient.self] }
        set { self[MultimodalAssetStoreClient.self] = newValue }
    }
}
