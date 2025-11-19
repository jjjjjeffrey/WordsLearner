//
//  ContentView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/12/25.
//

import ComposableArchitecture
import SwiftUI

struct WordComparatorMainView: View {
    @Bindable var store: StoreOf<WordComparatorFeature>
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    if !store.hasValidAPIKey {
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
            .onAppear {
                store.send(.onAppear)
            }
            .navigationDestination(
                store: store.scope(state: \.$destination.detail, action: \.destination.detail)
            ) { detailStore in
                ResponseDetailView(store: detailStore)
            }
            .sheet(
                item: $store.scope(state: \.destination?.settings, action: \.destination.settings)
            ) { settingsStore in
                SettingsView(store: settingsStore)
            }
        }
    }
    
    private var settingsButton: some View {
        Button {
            store.send(.settingsButtonTapped)
        } label: {
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
                store.send(.settingsButtonTapped)
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
    
    private var inputFieldsView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("First Word", systemImage: "1.circle")
                    .font(.headline)
                
                TextField("Enter first word (e.g., character)", text: $store.word1)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Second Word", systemImage: "2.circle")
                    .font(.headline)
                
                TextField("Enter second word (e.g., characteristics)", text: $store.word2)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Context Sentence", systemImage: "text.quote")
                    .font(.headline)
                
                TextField("Paste the sentence here", text: $store.sentence, axis: .vertical)
                    .textFieldStyle(CustomTextFieldStyle())
                    .lineLimit(3...6)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var generateButtonView: some View {
        Button {
            store.send(.generateButtonTapped)
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Generate Comparison")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((store.canGenerate && store.hasValidAPIKey) ? AppColors.primary : AppColors.separator)
            )
            .foregroundColor((store.canGenerate && store.hasValidAPIKey) ? .white : .gray)
        }
        .disabled(!store.canGenerate || !store.hasValidAPIKey)
    }
    
    private var recentComparisonsList: some View {
        Group {
            if !store.recentComparisons.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Recent Comparisons", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(store.recentComparisons) { comparison in
                            RecentComparisonRow(comparison: comparison) {
                                store.send(.loadRecentComparison(comparison.id))
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
    WordComparatorMainView(
        store: Store(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        }
    )
}

