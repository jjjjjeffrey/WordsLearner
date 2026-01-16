//
//  WordComparatorMainViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/14/26.
//

import SwiftUI
import ComposableArchitecture
import DependenciesTestSupport
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct WordComparatorMainViewTests {
    
    @Test
    func wordComparatorMainViewEmptyDefault() {
        let view = WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            } withDependencies: {
                $0.apiKeyManager = .testValue
                try! $0.bootstrapDatabase()
            }
        )
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
    
    @Test
    func wordComparatorMainViewRecentComparisons() {
        let view = WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            } withDependencies: {
                $0.apiKeyManager = .testValue
                try! $0.bootstrapDatabase(useTest: true)
            }
        )
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
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
                try! $0.bootstrapDatabase(useTest: true)
            }
        )
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
    
    @Test
    func wordComparatorMainViewMissingAPIKey() {
        let view = WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            } withDependencies: {
                $0.apiKeyManager = .testNoValidAPIKeyValue
                try! $0.bootstrapDatabase()
            }
        )
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
}
