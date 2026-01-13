//
//  WordsLearnerApp.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/12/25.
//

import SwiftUI
import ComposableArchitecture
import SQLiteData

@main
struct EnglishWordComparatorApp: App {
    init() {
        // Bootstrap database on app launch
        try! prepareDependencies {
            #if DEBUG
            $0.comparisonGenerator = .testValue
            try $0.bootstrapDatabase(useTest: true)
            #else
            try $0.bootstrapDatabase()
            #endif
        }
        
        // Start background task processing
        Task {
            @Dependency(\.backgroundTaskManager) var taskManager
            await taskManager.startProcessingLoop()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if !isTesting {
                WordComparatorMainView(
                    store: Store(initialState: WordComparatorFeature.State()) {
                        WordComparatorFeature()
                    }
                )
            }
        }
    }
}

