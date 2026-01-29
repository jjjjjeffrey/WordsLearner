//
//  BackgroundTasksViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/20/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif
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
            try! $0.bootstrapDatabase(useTest: true)
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
