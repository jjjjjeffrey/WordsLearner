//
//  WordComparatorViewModel.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/12/25.
//

import SwiftUI
import Foundation
import Combine

struct ComparisonHistory: Identifiable, Codable {
    let id = UUID()
    let word1: String
    let word2: String
    let sentence: String
    let response: String
    let date: Date
}

@MainActor
class WordComparatorViewModel: ObservableObject {
    @Published var word1: String = ""
    @Published var word2: String = ""
    @Published var sentence: String = ""
    @Published var streamingResponse: String = ""
    @Published var isLoading: Bool = false
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?
    @Published var shouldNavigateToDetail: Bool = false
    @Published var shouldStartStreaming: Bool = false
    @Published var recentComparisons: [ComparisonHistory] = []
    
    private let aiService = StreamingAIService()
    
    var canGenerate: Bool {
        !word1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !word2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init() {
        loadRecentComparisons()
    }
    
    func startComparison() {
        guard canGenerate else { return }
        
        streamingResponse = ""
        errorMessage = nil
        shouldStartStreaming = true
        shouldNavigateToDetail = true
    }
    
    func startStreamingComparison() {
        guard canGenerate && shouldStartStreaming else { return }
        
        isStreaming = true
        shouldStartStreaming = false
        
        let prompt = buildPrompt()
        
        Task {
            do {
                for try await chunk in aiService.streamResponse(prompt: prompt) {
                    self.streamingResponse += chunk
                }
                
                // Save to history when complete
                let comparison = ComparisonHistory(
                    word1: word1,
                    word2: word2,
                    sentence: sentence,
                    response: streamingResponse,
                    date: Date()
                )
                
                recentComparisons.insert(comparison, at: 0)
                if recentComparisons.count > 10 {
                    recentComparisons.removeLast()
                }
                saveRecentComparisons()
                
            } catch {
                self.errorMessage = error.localizedDescription
            }
            
            self.isStreaming = false
        }
    }
    
    func loadRecentComparison(at index: Int) {
        guard index < recentComparisons.count else { return }
        
        let comparison = recentComparisons[index]
        word1 = comparison.word1
        word2 = comparison.word2
        sentence = comparison.sentence
        streamingResponse = comparison.response
        shouldNavigateToDetail = true
    }
    
    private func buildPrompt() -> String {
        return """
        Help me compare the target English vocabularies "\(word1)" and "\(word2)" by telling me some simple stories that reveal what their means naturally in that specific context. And what's the key difference between them. These stories should illustrate not only the literal meaning but also the figurative meaning, if applicable.
        
        I'm an English learner, so tell this story at an elementary third-grade level, using only simple words and sentences, and without slang, phrasal verbs, or complex grammar.
        
        After the story, give any background or origin information (if it's known or useful), and explain the meaning of the vocabulary clearly.
        
        Finally, give 10 numbered example sentences that show the phrase used today in each context, with different tenses and sentence types, including questions. Use **bold** formatting for the target vocabulary throughout.

        If there are some situations we can use both of them without changing the meaning, and some other contexts which they can't be used interchangeably, please give me examples separately.

        At the end, tell me that if I can use them interchangeably in this sentence "\(sentence)"
        
        IMPORTANT: Format your response using proper Markdown syntax:
        - Use ## for main headings
        - Use ### for subheadings  
        - Use **text** for bold formatting
        - Use numbered lists (1. 2. 3.) for examples
        - Use - for bullet points when appropriate
        """
    }
    
    private func loadRecentComparisons() {
        if let data = UserDefaults.standard.data(forKey: "RecentComparisons"),
           let comparisons = try? JSONDecoder().decode([ComparisonHistory].self, from: data) {
            recentComparisons = comparisons
        }
    }
    
    private func saveRecentComparisons() {
        if let data = try? JSONEncoder().encode(recentComparisons) {
            UserDefaults.standard.set(data, forKey: "RecentComparisons")
        }
    }
}
