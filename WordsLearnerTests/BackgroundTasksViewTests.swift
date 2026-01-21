//
//  BackgroundTasksViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/20/26.
//

import SwiftUI
import ComposableArchitecture
import DependenciesTestSupport
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct BackgroundTasksViewTests {
    @Test
    func backgroundTasksViewEmpty() {
        let store = Store(
            initialState: BackgroundTasksFeature.State()
        ) {
            BackgroundTasksFeature()
        } withDependencies: {
            $0.backgroundTaskManager = .testValue
            try! $0.bootstrapDatabase()
        }

        let view = NavigationStack {
            BackgroundTasksView(store: store)
        }

        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }

    @Test
    func backgroundTasksViewSeededTasks() {
        let store = Store(
            initialState: BackgroundTasksFeature.State()
        ) {
            BackgroundTasksFeature()
        } withDependencies: {
            $0.backgroundTaskManager = .testValue
            try! $0.bootstrapDatabase(useTest: true)
        }

        let view = NavigationStack {
            BackgroundTasksView(store: store)
        }

        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
}

