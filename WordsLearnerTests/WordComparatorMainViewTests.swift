//
//  WordComparatorMainViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/14/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import ComposableArchitecture
import DependenciesTestSupport
import SnapshotTesting
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct WordComparatorMainViewTests {
    private var emptyLastReadComparisonStore: LastReadComparisonStoreClient {
        .init(
            get: { nil },
            set: { _ in },
            clear: {}
        )
    }

#if os(iOS)
    private func makeiOSMainViewController<V: View>(_ view: V) -> UIViewController {
        UIHostingController(rootView: view)
    }

    private func iOSMainViewSnapshotStrategy(
        style: UIUserInterfaceStyle
    ) -> Snapshotting<UIViewController, UIImage> {
        .wait(
            for: 0.2,
            on: .image(
                on: .iPhone12Pro,
                drawHierarchyInKeyWindow: true,
                traits: UITraitCollection(userInterfaceStyle: style)
            )
        )
    }
#endif
    
    @Test
    func wordComparatorMainViewEmptyDefault() {
        let view = WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            } withDependencies: {
                $0.apiKeyManager = .testValue
                $0.lastReadComparisonStore = emptyLastReadComparisonStore
                $0.backgroundTaskManager = .testValue
                $0.comparisonGenerator = .testValue
                try! $0.bootstrapDatabase(
                    useTest: true,
                    seed: { _ in }
                )
            }
        )
#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = CGSize(width: 1200, height: 800)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(
            of: makeiOSMainViewController(view),
            as: iOSMainViewSnapshotStrategy(style: .light)
        )
        assertSnapshot(
            of: makeiOSMainViewController(view),
            as: iOSMainViewSnapshotStrategy(style: .dark)
        )
#endif
    }
    
    @Test
    func wordComparatorMainViewRecentComparisons() {
        let now = Date(timeIntervalSince1970: 1_234_567_890)
        let view = WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            } withDependencies: {
                $0.apiKeyManager = .testValue
                $0.lastReadComparisonStore = emptyLastReadComparisonStore
                $0.backgroundTaskManager = .testValue
                $0.comparisonGenerator = .testValue
                try! $0.bootstrapDatabase(
                    useTest: true,
                    seed: { db in
                        try db.seed {
                            ComparisonHistory(
                                id: UUID(),
                                word1: "accept",
                                word2: "except",
                                sentence: "I accept all terms except the final clause.",
                                response: "Use 'accept' for receive/agree, 'except' for excluding.",
                                date: now,
                                isRead: false
                            )
                            ComparisonHistory(
                                id: UUID(),
                                word1: "affect",
                                word2: "effect",
                                sentence: "How does this affect the final effect?",
                                response: "'Affect' is usually a verb; 'effect' is usually a noun.",
                                date: now.addingTimeInterval(-3600),
                                isRead: true
                            )
                        }
                    }
                )
            }
        )
#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = CGSize(width: 1200, height: 800)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(
            of: makeiOSMainViewController(view),
            as: iOSMainViewSnapshotStrategy(style: .light)
        )
        assertSnapshot(
            of: makeiOSMainViewController(view),
            as: iOSMainViewSnapshotStrategy(style: .dark)
        )
#endif
    }
    
    @Test
    func wordComparatorMainViewReadyToGenerate() {
        let view = WordComparatorMainView(
            store: Store(initialState:
                    .init(
                        word1: "affect",
                        word2: "effect",
                        sentence: "The new policy will affect how the bonus takes effect.",
                        hasValidAPIKey: true)
            ) {
                WordComparatorFeature()
            } withDependencies: {
                $0.apiKeyManager = .testValue
                $0.lastReadComparisonStore = emptyLastReadComparisonStore
                $0.backgroundTaskManager = .testValue
                $0.comparisonGenerator = .testValue
                try! $0.bootstrapDatabase(
                    useTest: true,
                    seed: { _ in }
                )
            }
        )
#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = CGSize(width: 1200, height: 800)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(
            of: makeiOSMainViewController(view),
            as: iOSMainViewSnapshotStrategy(style: .light)
        )
        assertSnapshot(
            of: makeiOSMainViewController(view),
            as: iOSMainViewSnapshotStrategy(style: .dark)
        )
#endif
    }
    
    @Test
    func wordComparatorMainViewMissingAPIKey() {
        let view = WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            } withDependencies: {
                $0.apiKeyManager = .testNoValidAPIKeyValue
                $0.lastReadComparisonStore = emptyLastReadComparisonStore
                $0.backgroundTaskManager = .testValue
                $0.comparisonGenerator = .testValue
                try! $0.bootstrapDatabase(
                    useTest: true,
                    seed: { _ in }
                )
            }
        )
#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = CGSize(width: 1200, height: 800)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(
            of: makeiOSMainViewController(view),
            as: iOSMainViewSnapshotStrategy(style: .light)
        )
        assertSnapshot(
            of: makeiOSMainViewController(view),
            as: iOSMainViewSnapshotStrategy(style: .dark)
        )
#endif
    }

    @Test
    func wordComparatorMainViewComposerSheetDisplayed() {
        withDependencies {
            $0.apiKeyManager = .testValue
            $0.lastReadComparisonStore = emptyLastReadComparisonStore
            $0.backgroundTaskManager = .testValue
            $0.comparisonGenerator = .testValue
            try! $0.bootstrapDatabase(
                useTest: true,
                seed: { _ in }
            )
        } operation: {
            var state = WordComparatorFeature.State()
            state.word1 = "accept"
            state.word2 = "except"
            state.sentence = "I accept all terms except this one."
            state.hasValidAPIKey = true
            state.isComposerSheetPresented = true

            let view = WordComparatorMainView(
                store: Store(initialState: state) {
                    WordComparatorFeature()
                } withDependencies: {
                    $0.apiKeyManager = .testValue
                    $0.lastReadComparisonStore = emptyLastReadComparisonStore
                    $0.backgroundTaskManager = .testValue
                    $0.comparisonGenerator = .testValue
                    try! $0.bootstrapDatabase(
                        useTest: true,
                        seed: { _ in }
                    )
                }
            )
#if os(macOS)
            let hosting = NSHostingController(rootView: view)
            let size = CGSize(width: 1200, height: 800)
            assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS)
            // Root-view snapshots do not reliably capture SwiftUI sheet presentation on iOS.
            // The actual composer UI is covered by WordComparatorComposerSheetViewTests.
            _ = view
#endif
        }
    }
}
