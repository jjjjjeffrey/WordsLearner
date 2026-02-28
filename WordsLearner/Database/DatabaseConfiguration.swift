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

extension DependencyValues {
    /// Bootstrap the app database
    mutating func bootstrapDatabase(
        useTest: Bool = false,
        seed: (@Sendable (Database) throws -> Void)? = nil
    ) throws {
        @Dependency(\.context) var context
        let logger = Logger(subsystem: "WordsLearner", category: "Database")
        
        let database = try createAppDatabase(useTest: useTest, seed: seed)
        
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

func createAppDatabase(
    useTest: Bool,
    seed: (@Sendable (Database) throws -> Void)? = nil
) throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    let logger = Logger(subsystem: "WordsLearner", category: "Database")
    
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
    
    let database: any DatabaseWriter
    if context != .live && useTest {
        let temporaryRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let databaseDirectory = temporaryRoot.appendingPathComponent(
            "WordsLearnerTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: databaseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let databasePath = databaseDirectory.appendingPathComponent("WordsLearner.sqlite").path
        database = try SQLiteData.defaultDatabase(path: databasePath, configuration: configuration)
    } else {
        database = try SQLiteData.defaultDatabase(configuration: configuration)
    }
    
    var migrator = DatabaseMigrator()
    
//    #if DEBUG
//    migrator.eraseDatabaseOnSchemaChange = true
//    #endif
    
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
    
    // Migration to add isRead column to comparisonHistories
    migrator.registerMigration("v1.3 - Add isRead to comparisonHistories") { db in
        // Add isRead column with default value 0 (false/unread)
        try #sql(
            """
            ALTER TABLE "comparisonHistories" 
            ADD COLUMN "isRead" INTEGER NOT NULL DEFAULT 0
            """
        )
        .execute(db)
        
        // Set all existing records to unread (0)
        try #sql(
            """
            UPDATE "comparisonHistories" 
            SET "isRead" = 0
            """
        )
        .execute(db)
        
        // Create index for efficient filtering by read status
        try #sql(
            """
            CREATE INDEX "idx_comparisonHistories_isRead" 
            ON "comparisonHistories" ("isRead")
            """
        )
        .execute(db)
    }

    // Migration for multimodal lessons
    migrator.registerMigration("v1.4 - Create multimodal lessons tables") { db in
        try #sql(
            """
            CREATE TABLE "multimodalLessons" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "word1" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "word2" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "userSentence" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "status" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'generating',
                "storyboardJSON" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "stylePreset" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'simple_educational_illustration_v1',
                "voicePreset" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'elevenlabs_default_v1',
                "imageModel" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'google/gemini-2.5-flash-image',
                "audioModel" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'eleven_multilingual_v2',
                "generatorVersion" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'v1',
                "claritySelfRating" INTEGER,
                "lessonDurationSeconds" REAL,
                "errorMessage" TEXT,
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "updatedAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "completedAt" TEXT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_multimodalLessons_createdAt"
            ON "multimodalLessons" ("createdAt" DESC)
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_multimodalLessons_status"
            ON "multimodalLessons" ("status")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "multimodalLessonFrames" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "lessonID" TEXT NOT NULL,
                "frameIndex" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "frameRole" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "title" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "caption" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "narrationText" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "imagePrompt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "imageRelativePath" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "audioRelativePath" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "audioDurationSeconds" REAL,
                "checkPrompt" TEXT,
                "expectedAnswer" TEXT,
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "updatedAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_multimodalLessonFrames_lessonID"
            ON "multimodalLessonFrames" ("lessonID")
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
#if DEBUG
    // Seed preview data
    if context != .live && useTest {
        migrator.registerMigration("Seed some preview data") { db in
            if let seed {
                try seed(db)
            } else {
                try db.seedSampleData()
            }
        }
    }
#endif
    
    try migrator.migrate(database)
    
    return database
}

#if DEBUG
extension Database {
    nonisolated func seedSampleData() throws {
        // Seed some test data
        try seed {
            ComparisonHistory.Draft(
                word1: "character",
                word2: "characteristic",
                sentence: "The character of this wine is unique.",
                response: "Test response...",
                date: Date().addingTimeInterval(-3600),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "affect",
                word2: "effect",
                sentence: "How does this affect the result?",
                response: "Another test response...",
                date: Date(),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "emigrate",
                word2: "immigrate",
                sentence: "Many people emigrate to find better opportunities.",
                response: "A migrated test response...",
                date: Date().addingTimeInterval(-7200),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "infer",
                word2: "imply",
                sentence: "What do you infer from her words?",
                response: "Implied answer test...",
                date: Date().addingTimeInterval(-10800),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "stationary",
                word2: "stationery",
                sentence: "The bike remained stationary.",
                response: "More comparison data...",
                date: Date().addingTimeInterval(-14400),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "compliment",
                word2: "complement",
                sentence: "She gave me a sincere compliment on my presentation.",
                response: "Used 'compliment' for praise; 'complement' means completes/ pairs well.",
                date: Date().addingTimeInterval(-1800),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "principal",
                word2: "principle",
                sentence: "The principal announced a new school policy today.",
                response: "'Principal' is a person or main thing; 'principle' is a rule or belief.",
                date: Date().addingTimeInterval(-5400),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "its",
                word2: "it's",
                sentence: "The company updated its privacy policy last week.",
                response: "'Its' is possessive; 'it's' means 'it is' or 'it has'.",
                date: Date().addingTimeInterval(-9000),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "then",
                word2: "than",
                sentence: "Finish your tasks, then we can go for coffee.",
                response: "'Then' relates to time/sequence; 'than' is used for comparisons.",
                date: Date().addingTimeInterval(-12600),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "fewer",
                word2: "less",
                sentence: "This checkout line has fewer people than the other one.",
                response: "Use 'fewer' for countable items; 'less' for uncountable amounts.",
                date: Date().addingTimeInterval(-16200),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "discreet",
                word2: "discrete",
                sentence: "Please be discreet about the surprise party plans.",
                response: "'Discreet' = careful/private; 'discrete' = separate/distinct.",
                date: Date().addingTimeInterval(-19800),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "ensure",
                word2: "insure",
                sentence: "Double-check the settings to ensure the backup completes successfully.",
                response: "'Ensure' = make certain; 'insure' = provide insurance; 'assure' = reassure someone.",
                date: Date().addingTimeInterval(-23400),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "lay",
                word2: "lie",
                sentence: "I need to lie down for a few minutes.",
                response: "'Lie' = recline (no object); 'lay' = place something (needs an object).",
                date: Date().addingTimeInterval(-27000),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "allude",
                word2: "elude",
                sentence: "He alluded to a bigger announcement coming next month.",
                response: "'Allude' = refer indirectly; 'elude' = evade/escape or be difficult to remember.",
                date: Date().addingTimeInterval(-30600),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "council",
                word2: "counsel",
                sentence: "The city council voted on the new zoning proposal.",
                response: "'Council' = a governing group; 'counsel' = advice or a lawyer.",
                date: Date().addingTimeInterval(-34200),
                isRead: true
            )
            
            // Seed test background tasks
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
            )
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
            )
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
            )
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
        }
    }
}
#endif
