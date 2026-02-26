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
struct WordComparatorComposerSheetViewTests {
    @Test
    func composerSheetReadyToGenerate() {
        withDependencies {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: { _ in })
        } operation: {
            var state = WordComparatorFeature.State()
            state.word1 = "accept"
            state.word2 = "except"
            state.sentence = "I accept all terms except this one."
            state.hasValidAPIKey = true

            let view = WordComparatorComposerSheetView(
                store: Store(initialState: state) {
                    WordComparatorFeature()
                } withDependencies: {
                    $0.apiKeyManager = .testValue
                    try! $0.bootstrapDatabase(useTest: true, seed: { _ in })
                },
                onClose: {}
            )

            #if os(macOS)
            let hosting = NSHostingController(rootView: view)
            let size = CGSize(width: 720, height: 760)
            assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
            #elseif os(iOS)
            assertSnapshot(
                of: view,
                as: .image(
                    layout: .device(config: .iPhone12Pro),
                    traits: .init(userInterfaceStyle: .light)
                ),
                named: "iPhone12Pro.iOS26_2.light"
            )
            assertSnapshot(
                of: view,
                as: .image(
                    layout: .device(config: .iPhone12Pro),
                    traits: .init(userInterfaceStyle: .dark)
                ),
                named: "iPhone12Pro.iOS26_2.dark"
            )
            #endif
        }
    }

    @Test
    func composerSheetMissingAPIKey() {
        withDependencies {
            $0.apiKeyManager = .testNoValidAPIKeyValue
            try! $0.bootstrapDatabase(useTest: true, seed: { _ in })
        } operation: {
            let view = WordComparatorComposerSheetView(
                store: Store(initialState: .init()) {
                    WordComparatorFeature()
                } withDependencies: {
                    $0.apiKeyManager = .testNoValidAPIKeyValue
                    try! $0.bootstrapDatabase(useTest: true, seed: { _ in })
                },
                onClose: {}
            )

            #if os(macOS)
            let hosting = NSHostingController(rootView: view)
            let size = CGSize(width: 720, height: 760)
            assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
            #elseif os(iOS)
            assertSnapshot(
                of: view,
                as: .image(
                    layout: .device(config: .iPhone12Pro),
                    traits: .init(userInterfaceStyle: .light)
                ),
                named: "iPhone12Pro.iOS26_2.light"
            )
            assertSnapshot(
                of: view,
                as: .image(
                    layout: .device(config: .iPhone12Pro),
                    traits: .init(userInterfaceStyle: .dark)
                ),
                named: "iPhone12Pro.iOS26_2.dark"
            )
            #endif
        }
    }
}

