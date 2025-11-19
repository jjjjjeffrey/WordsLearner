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
        // Database is automatically initialized through dependency system
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
