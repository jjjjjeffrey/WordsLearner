//
//  ResponseDetailViewTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/16/26.
//

import SwiftUI
import ComposableArchitecture
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct ResponseDetailViewTests {
    
    @Test
    func responseDetailViewEmptyResponse() async {
        let store = Store(
            initialState: ResponseDetailFeature.State(
                word1: "character",
                word2: "characteristic",
                sentence: "This is a test sentence.",
                streamingResponse: "",
                isStreaming: false,
                errorMessage: nil,
                shouldStartStreaming: false
            )
        ) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .testValue
        }
        
        let view = NavigationStack {
            ResponseDetailView(store: store)
        }
        .frame(width: 390, height: 844)
        
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
    
    @Test
    func responseDetailViewWithResponse() async throws {
        let store = Store(
            initialState: ResponseDetailFeature.State(
                word1: "affect",
                word2: "effect",
                sentence: "The new policy will affect how the bonus takes effect.",
                streamingResponse: "",
                isStreaming: false,
                errorMessage: nil,
                shouldStartStreaming: true
            )
        ) {
            ResponseDetailFeature()
        } withDependencies: {
            $0.comparisonGenerator = .testValue
        }

        store.send(.onAppear)
        while store.state.isStreaming || store.state.streamingResponse.isEmpty {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        let view = NavigationStack {
            ResponseDetailView(store: store)
        }.frame(width: 390, height: 844)

        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
}

