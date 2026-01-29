//
//  RecentComparisonsViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/22/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif
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
struct RecentComparisonsViewTests {
    @Test
    func recentComparisonsViewEmpty() {
        let store = Store(
            initialState: RecentComparisonsFeature.State()
        ) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(
                useTest: true,
                seed: { _ in }
            )
        }

        let view = RecentComparisonsView(store: store)
            .padding()
            .frame(width: 390)

#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = measuredFittingSize(for: view, width: 390)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
#endif
    }

    @Test
    func recentComparisonsViewSeeded() {
        @Dependency(\.date.now) var now
        let store = Store(
            initialState: RecentComparisonsFeature.State()
        ) {
            RecentComparisonsFeature()
        } withDependencies: {
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

        let view = RecentComparisonsView(store: store)
            .padding()
            .frame(width: 390)

#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = measuredFittingSize(for: view, width: 390)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
#endif
    }
}
