//
//  DependencyPreviewIntegrationTests.swift
//  WordsLearnerTests
//

import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
struct DependencyPreviewIntegrationTests {
    private final class IncrementingDateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var counter: TimeInterval = 0

        func next() -> Date {
            lock.lock()
            defer {
                counter += 1
                lock.unlock()
            }
            return Date(timeIntervalSince1970: 1_700_000_000 + counter)
        }
    }

    @Test
    func comparisonGeneratorPreviewValueStreamsAndSavesToHistory() async throws {
        try await withDependencies {
            $0.date = DateGenerator { Date(timeIntervalSince1970: 1_700_000_000) }
            try $0.bootstrapDatabase(useTest: true, seed: { _ in })
        } operation: {
            @Dependency(\.defaultDatabase) var database

            let generator = ComparisonGenerationServiceClient.previewValue
            var streamed = ""
            for try await chunk in generator.generateComparison("character", "characteristic", "test") {
                streamed += chunk
            }
            let expected = AIServiceClient.previewStreamString.trimmingCharacters(in: .whitespacesAndNewlines)
            let actual = streamed.trimmingCharacters(in: .whitespacesAndNewlines)

            #expect(!actual.isEmpty)
            #expect(actual.contains("Character"))
            #expect(actual == expected)

            try await generator.saveToHistory("character", "characteristic", "test", streamed)

            let rows = try await database.read { db in
                try ComparisonHistory
                    .where { $0.word1 == "character" && $0.word2 == "characteristic" }
                    .fetchAll(db)
            }

            #expect(rows.count == 1)
            #expect(rows[0].response.trimmingCharacters(in: .whitespacesAndNewlines) == expected)
        }
    }

    @Test
    func backgroundTaskManagerPreviewValueUsesPreviewGeneratorAndPersistsResults() async throws {
        try await withDependencies {
            $0.date = DateGenerator { Date(timeIntervalSince1970: 1_700_000_000) }
            try $0.bootstrapDatabase(useTest: true, seed: { _ in })
        } operation: {
            @Dependency(\.defaultDatabase) var database

            let manager = BackgroundTaskManagerClient.previewValue
            try await manager.addTask("accept", "except", "I accept all terms except this one.")

            let pendingBefore = try await database.read { db in
                try BackgroundTask
                    .where { $0.status == BackgroundTask.Status.pending.rawValue }
                    .count()
                    .fetchOne(db) ?? 0
            }
            #expect(pendingBefore == 1)

            await manager.startProcessingLoop()
            defer { Task { await manager.stopProcessingLoop() } }

            let deadline = ContinuousClock.now + .seconds(8)
            var completedTask: BackgroundTask?
            var savedHistory: ComparisonHistory?

            while ContinuousClock.now < deadline {
                let result = try await database.read { db in
                    let task = try BackgroundTask
                        .where { $0.word1 == "accept" && $0.word2 == "except" }
                        .order { $0.createdAt.desc() }
                        .limit(1)
                        .fetchOne(db)
                    let history = try ComparisonHistory
                        .where { $0.word1 == "accept" && $0.word2 == "except" }
                        .order { $0.date.desc() }
                        .limit(1)
                        .fetchOne(db)
                    return (task, history)
                }

                completedTask = result.0
                savedHistory = result.1

                if completedTask?.status == BackgroundTask.Status.completed.rawValue, savedHistory != nil {
                    break
                }

                try? await Task.sleep(for: .milliseconds(100))
            }

            await manager.stopProcessingLoop()

            #expect(completedTask != nil)
            #expect(completedTask?.status == BackgroundTask.Status.completed.rawValue)
            #expect(savedHistory != nil)
            #expect(
                savedHistory?.response.trimmingCharacters(in: .whitespacesAndNewlines)
                    == AIServiceClient.previewStreamString.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    @Test
    func comparisonGeneratorPreviewValueUsesFreshDateForEachSave() async throws {
        let box = IncrementingDateBox()

        try await withDependencies {
            $0.date = DateGenerator { box.next() }
            try $0.bootstrapDatabase(useTest: true, seed: { _ in })
        } operation: {
            @Dependency(\.defaultDatabase) var database

            let generator = ComparisonGenerationServiceClient.previewValue
            try await generator.saveToHistory("accept", "except", "first", "response-1")
            try await generator.saveToHistory("accept", "except", "second", "response-2")

            let rows = try await database.read { db in
                try ComparisonHistory
                    .where { $0.word1 == "accept" && $0.word2 == "except" }
                    .order { $0.date.asc() }
                    .fetchAll(db)
            }

            #expect(rows.count == 2)
            #expect(rows[0].date != rows[1].date)
            #expect(rows[0].date == Date(timeIntervalSince1970: 1_700_000_000))
            #expect(rows[1].date == Date(timeIntervalSince1970: 1_700_000_001))
        }
    }
}
