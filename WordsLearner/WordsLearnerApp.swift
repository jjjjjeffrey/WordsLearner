//
//  WordsLearnerApp.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/12/25.
//

import SwiftUI
import ComposableArchitecture

@main
struct EnglishWordComparatorApp: App {
    var body: some Scene {
        WindowGroup {
            WordComparatorMainView(
                store: Store(initialState: WordComparatorFeature.State()) {
                    WordComparatorFeature()
                }
            )
        }
    }
}


