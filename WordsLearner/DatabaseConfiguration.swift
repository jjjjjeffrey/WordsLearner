//
//  DatabaseConfiguration.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/19/25.
//

import Foundation
import SQLiteData
import ComposableArchitecture
import OSLog

private let logger = Logger(subsystem: "WordsLearner", category: "Database")

extension DependencyValues {
    var database: DatabaseWriter {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }
}

private enum DatabaseKey: DependencyKey {
    static let liveValue: DatabaseWriter = {
        do {
            let database = try createAppDatabase()
            logger.info("✅ Database initialized at: \(database.path)")
            return database
        } catch {
            logger.error("❌ Failed to initialize database: \(error)")
            fatalError("Failed to initialize database: \(error)")
        }
    }()
    
    static let testValue: DatabaseWriter = {
        try! DatabaseQueue()
    }()
}

/// Creates and configures the app database
private func createAppDatabase() throws -> DatabaseQueue {
    // Get application support directory
    let fileManager = FileManager.default
    let appSupportURL = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    
    // Create app-specific directory
    let appDirectory = appSupportURL.appendingPathComponent("WordsLearner", isDirectory: true)
    try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
    
    // Database file path
    let databaseURL = appDirectory.appendingPathComponent("comparisons.sqlite")
    
    // Create database
    let databaseQueue = try DatabaseQueue(path: databaseURL.path)
    
    // Run migrations
    var migrator = DatabaseMigrator()
    
    #if DEBUG
    // Erase database on schema change during development
    migrator.eraseDatabaseOnSchemaChange = true
    #endif
    
    // Register migrations
    migrator.registerMigration("v1.0 - Create comparisonHistories table") { db in
        try #sql(
            """
            CREATE TABLE "comparisonHistories" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "word1" TEXT NOT NULL,
                "word2" TEXT NOT NULL,
                "sentence" TEXT NOT NULL,
                "response" TEXT NOT NULL,
                "date" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)
        
        // Create index for faster date-based queries
        try #sql(
            """
            CREATE INDEX "idx_comparisonHistories_date" 
            ON "comparisonHistories" ("date" DESC)
            """
        )
        .execute(db)
    }
    
    // Future migrations can be added here
    // migrator.registerMigration("v1.1 - Add new column") { db in ... }
    
    try migrator.migrate(databaseQueue)
    
    return databaseQueue
}

// MARK: - Database Operations Helper

extension DatabaseWriter where Self == DatabaseQueue {
    /// Test database for previews and tests
    static var testDatabase: Self {
        let database = try! DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("Create test table") { db in
            try #sql(
                """
                CREATE TABLE "comparisonHistories" (
                    "id" TEXT PRIMARY KEY NOT NULL,
                    "word1" TEXT NOT NULL,
                    "word2" TEXT NOT NULL,
                    "sentence" TEXT NOT NULL,
                    "response" TEXT NOT NULL,
                    "date" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
        }
        try! migrator.migrate(database)
        return database
    }
}

// MARK: - Migration Helper (Optional)

extension DatabaseWriter where Self == DatabaseQueue {
    /// Migrate data from UserDefaults to SQLite (run once)
    func migrateFromUserDefaults() throws {
        guard let data = UserDefaults.standard.data(forKey: "RecentComparisons"),
              let oldComparisons = try? JSONDecoder().decode([ComparisonHistoryLegacy].self, from: data)
        else {
            logger.info("No legacy data to migrate")
            return
        }
        
        try write { db in
            for comparison in oldComparisons {
                try ComparisonHistory.insert {
                    ComparisonHistory.Draft(
                        id: comparison.id,
                        word1: comparison.word1,
                        word2: comparison.word2,
                        sentence: comparison.sentence,
                        response: comparison.response,
                        date: comparison.date
                    )
                }
                .execute(db)
            }
        }
        
        // Remove old data after successful migration
        UserDefaults.standard.removeObject(forKey: "RecentComparisons")
        logger.info("✅ Migrated \(oldComparisons.count) records from UserDefaults")
    }
}

// Legacy model for migration
private struct ComparisonHistoryLegacy: Codable {
    let id: UUID
    let word1: String
    let word2: String
    let sentence: String
    let response: String
    let date: Date
}
