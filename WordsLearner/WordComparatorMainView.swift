//
//  ContentView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/12/25.
//

import SwiftUI

struct WordComparatorMainView: View {
    @StateObject private var viewModel = WordComparatorViewModel()
    @StateObject private var apiKeyManager = APIKeyManager.shared
    @State private var showingSettings = false
    
    var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        headerView
                        
                        if !apiKeyManager.hasValidAPIKey {
                            apiKeyWarningView
                        }
                        
                        inputFieldsView
                        generateButtonView
                        recentComparisonsList
                    }
                    .padding()
                }
                .navigationTitle("Word Comparator")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        settingsButton
                    }
                    #else
                    ToolbarItem(placement: .primaryAction) {
                        settingsButton
                    }
                    #endif
                }
                .navigationDestination(isPresented: $viewModel.shouldNavigateToDetail) {
                    ResponseDetailView(viewModel: viewModel)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
            }
        }
        
        private var settingsButton: some View {
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gear")
                    .foregroundColor(.primary)
            }
        }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("AI English Word Comparator")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Compare similar English words with AI assistance")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var apiKeyWarningView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("API Key Required")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("Please configure your AIHubMix API key in settings to use this app")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open Settings") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.warning.opacity(0.1))
        )
    }
    
    // ... rest of the views remain the same
    
    private var inputFieldsView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("First Word", systemImage: "1.circle")
                    .font(.headline)
                
                TextField("Enter first word (e.g., character)", text: $viewModel.word1)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Second Word", systemImage: "2.circle")
                    .font(.headline)
                
                TextField("Enter second word (e.g., characteristics)", text: $viewModel.word2)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Context Sentence", systemImage: "text.quote")
                    .font(.headline)
                
                TextField("Paste the sentence here", text: $viewModel.sentence, axis: .vertical)
                    .textFieldStyle(CustomTextFieldStyle())
                    .lineLimit(3...6)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var generateButtonView: some View {
        Button(action: {
            viewModel.startComparison()
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                }
                
                Text(viewModel.isLoading ? "Generating..." : "Generate Comparison")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((viewModel.canGenerate && apiKeyManager.hasValidAPIKey) ? AppColors.primary : AppColors.separator)
            )
            .foregroundColor((viewModel.canGenerate && apiKeyManager.hasValidAPIKey) ? .white : .gray)
        }
        .disabled(!viewModel.canGenerate || viewModel.isLoading || !apiKeyManager.hasValidAPIKey)
    }
    
    private var recentComparisonsList: some View {
        Group {
            if !viewModel.recentComparisons.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Recent Comparisons", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.recentComparisons.indices, id: \.self) { index in
                            RecentComparisonRow(comparison: viewModel.recentComparisons[index]) {
                                viewModel.loadRecentComparison(at: index)
                            }
                        }
                    }
                }
                .padding(.top)
            }
        }
    }
}




#Preview {
    WordComparatorMainView()
}
