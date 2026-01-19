//
//  BackgroundTaskRowTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/16/26.
//

import SwiftUI
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct BackgroundTaskRowTests {
    
    @Test
    func backgroundTaskRowAllStates() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let tasks: [WordsLearner.BackgroundTask] = [
            WordsLearner.BackgroundTask(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                word1: "accept",
                word2: "except",
                sentence: "I accept all of the terms.",
                status: WordsLearner.BackgroundTask.Status.pending.rawValue,
                response: "",
                error: nil,
                createdAt: now,
                updatedAt: now
            ),
            WordsLearner.BackgroundTask(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                word1: "advice",
                word2: "advise",
                sentence: "Please give me some advice.",
                status: WordsLearner.BackgroundTask.Status.generating.rawValue,
                response: "",
                error: nil,
                createdAt: now,
                updatedAt: now
            ),
            WordsLearner.BackgroundTask(
                id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
                word1: "affect",
                word2: "effect",
                sentence: "How does this affect you?",
                status: WordsLearner.BackgroundTask.Status.completed.rawValue,
                response: "Some automated response.",
                error: nil,
                createdAt: now,
                updatedAt: now
            ),
            WordsLearner.BackgroundTask(
                id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
                word1: "stationary",
                word2: "stationery",
                sentence: "The car is stationary.",
                status: WordsLearner.BackgroundTask.Status.failed.rawValue,
                response: "",
                error: "Network error",
                createdAt: now,
                updatedAt: now
            )
        ]
        
        let view = VStack(spacing: 16) {
            ForEach(tasks) { task in
                BackgroundTaskRow(
                    task: task,
                    onRemove: {},
                    onTap: {},
                    onRegenerate: {}
                )
            }
        }
        .padding()
        .frame(width: 500)
        .background(AppColors.background)
        
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
}

