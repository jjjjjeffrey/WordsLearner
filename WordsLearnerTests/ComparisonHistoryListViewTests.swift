//
//  ComparisonHistoryListViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/21/26.
//

import SwiftUI
import ComposableArchitecture
import DependenciesTestSupport
import SnapshotTesting
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
@Suite(
    .dependency(\.date.now, Date(timeIntervalSince1970: 1_234_567_890))
)
struct ComparisonHistoryListViewTests {
    @Test
    func comparisonHistoryListViewSeeded() {
        @Dependency(\.date.now) var now
        let store = Store(
            initialState: ComparisonHistoryListFeature.State()
        ) {
            ComparisonHistoryListFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(
                useTest: true,
                seed: { db in
                    try db.seed {
                        ComparisonHistory(
                            id: UUID(),
                            word1: "accept",
                            word2: "except",
                            sentence: "I accept all terms.",
                            response: "Use 'accept' for receive/agree, 'except' for excluding.",
                            date: now.addingTimeInterval(-3600),
                            isRead: false
                        )
                        ComparisonHistory(
                            id: UUID(),
                            word1: "affect",
                            word2: "effect",
                            sentence: "How does this affect the result?",
                            response: "'Affect' is usually a verb; 'effect' is usually a noun.",
                            date: now,
                            isRead: true
                        )
                    }
                }
            )
        }

        let view = NavigationStack {
            ComparisonHistoryListView(store: store)
        }

        assertSnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .light)),
            named: "1"
        )
        assertSnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .dark)),
            named: "2"
        )
    }
    
    @Test
    func comparisonHistoryListViewEmpty() {
        let store = Store(
            initialState: ComparisonHistoryListFeature.State()
        ) {
            ComparisonHistoryListFeature()
        }

        let view = NavigationStack {
            ComparisonHistoryListView(store: store)
        }

        assertSnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .light)),
            named: "1"
        )
        assertSnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .dark)),
            named: "2"
        )
    }
}
