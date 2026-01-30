//
//  BackgroundTasksViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/20/26.
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif
import ComposableArchitecture
import DependenciesTestSupport
import SQLiteData
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct BackgroundTasksViewTests {
    private let seedBaseDate = Date(timeIntervalSince1970: 1_700_000_000)
    
    private func seedBackgroundTasks(in db: Database) throws {
        let now = seedBaseDate
        try db.seed {
            BackgroundTask.Draft(
                id: UUID(),
                word1: "accept",
                word2: "except",
                sentence: "I accept all terms.",
                status: BackgroundTask.Status.pending.rawValue,
                response: "",
                error: nil,
                createdAt: now,
                updatedAt: now
            )
            BackgroundTask.Draft(
                id: UUID(),
                word1: "advice",
                word2: "advise",
                sentence: "Can you give me some advice?",
                status: BackgroundTask.Status.completed.rawValue,
                response: "Test response for advice vs advise...",
                error: nil,
                createdAt: now.addingTimeInterval(-3600),
                updatedAt: now.addingTimeInterval(-1800)
            )
            BackgroundTask.Draft(
                id: UUID(),
                word1: "complement",
                word2: "compliment",
                sentence: "Your shoes complement the outfit.",
                status: BackgroundTask.Status.generating.rawValue,
                response: "",
                error: nil,
                createdAt: now.addingTimeInterval(-7200),
                updatedAt: now.addingTimeInterval(-3600)
            )
            BackgroundTask.Draft(
                id: UUID(),
                word1: "principle",
                word2: "principal",
                sentence: "Honesty is the best principle.",
                status: BackgroundTask.Status.failed.rawValue,
                response: "",
                error: "Simulated failure during generation.",
                createdAt: now.addingTimeInterval(-10800),
                updatedAt: now.addingTimeInterval(-7200)
            )
        }
    }
    
    @Test
    func backgroundTasksViewEmpty() {
        let store = Store(
            initialState: BackgroundTasksFeature.State()
        ) {
            BackgroundTasksFeature()
        } withDependencies: {
            $0.backgroundTaskManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: { _ in })
        }

        let view = NavigationStack {
            BackgroundTasksView(store: store)
        }

#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = measuredFittingSize(for: view, width: 500)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
#endif
    }

    @Test
    func backgroundTasksViewSeededTasks() {
        let store = Store(
            initialState: BackgroundTasksFeature.State()
        ) {
            BackgroundTasksFeature()
        } withDependencies: {
            $0.backgroundTaskManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }

        let view = NavigationStack {
            BackgroundTasksView(store: store)
        }

#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = measuredFittingSize(for: view, width: 500)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
#endif
    }
}
