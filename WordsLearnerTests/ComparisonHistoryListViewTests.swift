//
//  ComparisonHistoryListViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/21/26.
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
@Suite(
    .dependency(\.date.now, Date(timeIntervalSince1970: 1_234_567_890))
)
struct ComparisonHistoryListViewTests {
#if os(iOS)
    private func makeiOSPushedNavigationController<V: View>(_ view: V) -> UIViewController {
        let root = UIViewController()
        root.view.backgroundColor = .systemBackground
        root.navigationItem.title = "Root"
        if #available(iOS 14.0, *) {
            root.navigationItem.backButtonDisplayMode = .minimal
        }

        let navigationController = UINavigationController(rootViewController: root)
        let hosted = UIHostingController(rootView: view)
        navigationController.pushViewController(hosted, animated: false)
        navigationController.navigationBar.prefersLargeTitles = false
        return navigationController
    }

    private func iOSSnapshotStrategy(
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

        let contentView = ComparisonHistoryListView(store: store)

#if os(macOS)
        let view = NavigationStack { contentView }
        let hosting = NSHostingController(rootView: view)
        let size = measuredFittingSize(for: view, width: 500)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(
            of: makeiOSPushedNavigationController(contentView),
            as: iOSSnapshotStrategy(style: .light),
            named: "1"
        )
        assertSnapshot(
            of: makeiOSPushedNavigationController(contentView),
            as: iOSSnapshotStrategy(style: .dark),
            named: "2"
        )
#endif
    }
    
    @Test
    func comparisonHistoryListViewEmpty() {
        let store = Store(
            initialState: ComparisonHistoryListFeature.State()
        ) {
            ComparisonHistoryListFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(
                useTest: true,
                seed: { _ in }
            )
        }

        let contentView = ComparisonHistoryListView(store: store)

#if os(macOS)
        let view = NavigationStack { contentView }
        let hosting = NSHostingController(rootView: view)
        let size = measuredFittingSize(for: view, width: 500)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(
            of: makeiOSPushedNavigationController(contentView),
            as: iOSSnapshotStrategy(style: .light),
            named: "1"
        )
        assertSnapshot(
            of: makeiOSPushedNavigationController(contentView),
            as: iOSSnapshotStrategy(style: .dark),
            named: "2"
        )
#endif
    }
}
