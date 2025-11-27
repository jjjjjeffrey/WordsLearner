//
//  DatabaseConfiguration.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/19/25.
//

import Dependencies
import Foundation
import IssueReporting
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "WordsLearner", category: "Database")

extension DependencyValues {
    /// Bootstrap the app database
    mutating func bootstrapDatabase() throws {
        @Dependency(\.context) var context
        
        let database = try createAppDatabase()
        
        logger.debug(
            """
            App database:
            open "\(database.path)"
            """
        )
        
        defaultDatabase = database
    }
}

/// Creates and configures the app database
private func createAppDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    
    #if DEBUG
    configuration.prepareDatabase { db in
        db.trace(options: .profile) { event in
            if context == .live {
                logger.debug("\(event.expandedDescription)")
            } else {
                print("\(event.expandedDescription)")
            }
        }
    }
    #endif // DEBUG
    
    let database = try SQLiteData.defaultDatabase(configuration: configuration)
    
    var migrator = DatabaseMigrator()
    
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif
    
    // Register migrations
    migrator.registerMigration("v1.0 - Create comparisonHistories table") { db in
        try #sql(
            """
            CREATE TABLE "comparisonHistories" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "word1" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "word2" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "sentence" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "response" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "date" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
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
        
        // Create index for word searches
        try #sql(
            """
            CREATE INDEX "idx_comparisonHistories_words" 
            ON "comparisonHistories" ("word1", "word2")
            """
        )
        .execute(db)
    }
    
    // Migration for background tasks table
    migrator.registerMigration("v1.2 - Create backgroundTasks table") { db in
        try #sql(
            """
            CREATE TABLE "backgroundTasks" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "word1" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "word2" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "sentence" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "status" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'pending',
                "response" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "error" TEXT,
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "updatedAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
            ) STRICT
            """
        )
        .execute(db)
        
        // Create index for status queries
        try #sql(
            """
            CREATE INDEX "idx_backgroundTasks_status" 
            ON "backgroundTasks" ("status")
            """
        )
        .execute(db)
        
        // Create index for date-based queries
        try #sql(
            """
            CREATE INDEX "idx_backgroundTasks_createdAt" 
            ON "backgroundTasks" ("createdAt" DESC)
            """
        )
        .execute(db)
    }
    
    // Optional: Create Full-Text Search table for advanced search
    migrator.registerMigration("v1.1 - Create FTS table") { db in
        try #sql(
            """
            CREATE VIRTUAL TABLE "comparisonHistories_fts" USING fts5(
                "word1",
                "word2",
                "sentence",
                "response",
                content="comparisonHistories",
                content_rowid="rowid"
            )
            """
        )
        .execute(db)
        
        // Create triggers to keep FTS in sync
        try ComparisonHistory.createTemporaryTrigger(
            after: .insert { new in
                #sql(
                    """
                    INSERT INTO comparisonHistories_fts(rowid, word1, word2, sentence, response)
                    VALUES (\(new.rowid), \(new.word1), \(new.word2), \(new.sentence), \(new.response))
                    """
                )
            }
        )
        .execute(db)
        
        try ComparisonHistory.createTemporaryTrigger(
            after: .update { ($0.word1, $0.word2, $0.sentence, $0.response) }
            forEachRow: { _, new in
                #sql(
                    """
                    UPDATE comparisonHistories_fts 
                    SET word1 = \(new.word1), 
                        word2 = \(new.word2), 
                        sentence = \(new.sentence), 
                        response = \(new.response)
                    WHERE rowid = \(new.rowid)
                    """
                )
            }
        )
        .execute(db)
        
        try ComparisonHistory.createTemporaryTrigger(
            after: .delete { old in
                #sql("DELETE FROM comparisonHistories_fts WHERE rowid = \(old.rowid)")
            }
        )
        .execute(db)
    }
    
    try migrator.migrate(database)
    
    return database
}

// MARK: - Test Database

extension DatabaseWriter where Self == DatabaseQueue {
    /// Test database for previews and tests
    static var testDatabase: Self {
        let database = try! DatabaseQueue()
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("Create test tables") { db in
            // ComparisonHistory table
            try #sql(
                """
                CREATE TABLE "comparisonHistories" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "word1" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "word2" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "sentence" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "response" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "date" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
                ) STRICT
                """
            )
            .execute(db)
            
            // BackgroundTask table
            try #sql(
                """
                CREATE TABLE "backgroundTasks" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "word1" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "word2" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "sentence" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "status" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'pending',
                    "response" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "error" TEXT,
                    "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                    "updatedAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
                ) STRICT
                """
            )
            .execute(db)
            
            // Seed some test data
            try ComparisonHistory.insert {
                [
                    ComparisonHistory.Draft(
                        word1: "character",
                        word2: "characteristic",
                        sentence: "The character of this wine is unique.",
                        response: "Test response...",
                        date: Date()
                    ),
                    ComparisonHistory.Draft(
                        word1: "affect",
                        word2: "effect",
                        sentence: "How does this affect the result?",
                        response: "Another test response...",
                        date: Date().addingTimeInterval(-3600)
                    )
                ]
            }
            .execute(db)
            
            // Seed test background tasks
            try BackgroundTask.insert {
                [
                    BackgroundTask.Draft(
                        id: UUID(),
                        word1: "accept",
                        word2: "except",
                        sentence: "I accept all terms.",
                        status: BackgroundTask.Status.pending.rawValue,
                        response: "",
                        error: nil,
                        createdAt: Date(),
                        updatedAt: Date()
                    ),
                    BackgroundTask.Draft(
                        id: UUID(),
                        word1: "advice",
                        word2: "advise",
                        sentence: "Can you give me some advice?",
                        status: BackgroundTask.Status.completed.rawValue,
                        response: "Test response for advice vs advise...",
                        error: nil,
                        createdAt: Date().addingTimeInterval(-3600),
                        updatedAt: Date().addingTimeInterval(-1800)
                    ),
                    BackgroundTask.Draft(
                        id: UUID(),
                        word1: "complement",
                        word2: "compliment",
                        sentence: "Your shoes complement the outfit.",
                        status: BackgroundTask.Status.generating.rawValue,
                        response: "",
                        error: nil,
                        createdAt: Date().addingTimeInterval(-7200),
                        updatedAt: Date().addingTimeInterval(-3600)
                    ),
                    BackgroundTask.Draft(
                        id: UUID(),
                        word1: "principle",
                        word2: "principal",
                        sentence: "Honesty is the best principle.",
                        status: BackgroundTask.Status.failed.rawValue,
                        response: "",
                        error: "Simulated failure during generation.",
                        createdAt: Date().addingTimeInterval(-10800),
                        updatedAt: Date().addingTimeInterval(-7200)
                    )
                ]
            }
            .execute(db)
        }
        
        try! migrator.migrate(database)
        return database
    }
}
