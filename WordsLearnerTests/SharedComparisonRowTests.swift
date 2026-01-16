//
//  SharedComparisonRowTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/16/26.
//

import SwiftUI
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct SharedComparisonRowTests {
    
    @Test
    func sharedComparisonRowUnread() {
        let comparison = ComparisonHistory(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            word1: "character",
            word2: "characteristic",
            sentence: "The character of this wine is unique and shows the winery's attention to detail.",
            response: "Sample response",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            isRead: false
        )
        
        let view = SharedComparisonRow(comparison: comparison) {}
            .padding()
            .frame(width: 420)
        
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
    
    @Test
    func sharedComparisonRowRead() {
        let comparison = ComparisonHistory(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            word1: "affect",
            word2: "effect",
            sentence: "How does this change affect the final result?",
            response: "Another response",
            date: Date(timeIntervalSince1970: 1_700_000_000 - 3600),
            isRead: true
        )
        
        let view = SharedComparisonRow(comparison: comparison) {}
            .padding()
            .frame(width: 420)
        
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
}

