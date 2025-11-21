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
    init() {
        // Bootstrap database on app launch
        try! prepareDependencies {
            try $0.bootstrapDatabase()
        }
    }
    
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
