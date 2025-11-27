//
//  ContentView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/12/25.
//

import ComposableArchitecture
import SwiftUI
import SQLiteData

struct WordComparatorMainView: View {
    @Bindable var store: StoreOf<WordComparatorFeature>
    
    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    if !store.hasValidAPIKey {
                        apiKeyWarningView
                    }
                    
                    inputFieldsView
                    generateButtonsView
                    
                    RecentComparisonsView(
                        store: store.scope(
                            state: \.recentComparisons,
                            action: \.recentComparisons
                        )
                    )
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
                    HStack(spacing: 16) {
                        backgroundTasksButton
                        historyButton
                        settingsButton
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        backgroundTasksButton
                        historyButton
                        settingsButton
                    }
                }
                #endif
            }
            .onAppear {
                store.send(.onAppear)
            }
        } destination: { store in
            switch store.case {
            case let .detail(detailStore):
                ResponseDetailView(store: detailStore)
            case let .historyList(historyStore):
                ComparisonHistoryListView(store: historyStore)
            case let .backgroundTasks(backgroundTasksStore):
                BackgroundTasksView(store: backgroundTasksStore)
            }
        }
        .sheet(
            item: $store.scope(state: \.settings, action: \.settings)
        ) { settingsStore in
            SettingsView(store: settingsStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    // MARK: - Toolbar Buttons
    
    private var backgroundTasksButton: some View {
        Button {
            store.send(.backgroundTasksButtonTapped)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.primary)
                
                // Badge for pending tasks count
                if store.pendingTasksCount > 0 {
                    Text("\(store.pendingTasksCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(AppColors.error))
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
    
    private var historyButton: some View {
        Button {
            store.send(.historyListButtonTapped)
        } label: {
            Image(systemName: "clock")
                .foregroundColor(.primary)
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
    
    // MARK: - Content Views
    
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
    
    private var generateButtonsView: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.generateButtonTapped)
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate")
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
            
            Button {
                store.send(.generateInBackgroundButtonTapped)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                    
                    #if os(iOS)
                    if horizontalSizeClass == .regular {
                        Text("Background")
                            .fontWeight(.semibold)
                    }
                    #else
                    Text("Background")
                        .fontWeight(.semibold)
                    #endif
                    
                    if store.pendingTasksCount > 0 {
                        Text("(\(store.pendingTasksCount))")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                .frame(minWidth: platformButtonWidth())
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((store.canGenerate && store.hasValidAPIKey) ?
                              AppColors.secondary : AppColors.separator)
                )
                .foregroundColor((store.canGenerate && store.hasValidAPIKey) ?
                                .white : .gray)
            }
            .disabled(!store.canGenerate || !store.hasValidAPIKey)
        }
    }
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    private func platformButtonWidth() -> CGFloat {
        #if os(iOS)
        return 50
        #else
        return 120
        #endif
    }
}

#if DEBUG
private func wordComparatorPreviewStore(
    for state: WordComparatorFeature.State
) -> StoreOf<WordComparatorFeature> {
    return Store(initialState: state) {
        WordComparatorFeature()
    }
}

private extension WordComparatorFeature.State {
    static var previewEmpty: Self {
        Self()
    }
    
    static var previewReadyToGenerate: Self {
        var state = Self()
        state.word1 = "affect"
        state.word2 = "effect"
        state.sentence = "The new policy will affect how the bonus takes effect."
        state.hasValidAPIKey = true
        return state
    }
    
    static var previewMissingAPIKey: Self {
        var state = Self.previewReadyToGenerate
        state.hasValidAPIKey = false
        return state
    }
    
    static var previewRecentComparisons: Self {
        var state = Self.previewEmpty
        state.hasValidAPIKey = true
        return state
    }
}

#Preview("Empty / Default") {
    withDependencies {
        $0.apiKeyManager = .testValue
    } operation: {
        WordComparatorMainView(
            store: wordComparatorPreviewStore(for: .init())
        )
    }
}

#Preview("Ready to Generate") {
    withDependencies {
        $0.apiKeyManager = .testValue
    } operation: {
        WordComparatorMainView(
            store: wordComparatorPreviewStore(for: .init(word1: "affect", word2: "effect", sentence: "The new policy will affect how the bonus takes effect.", hasValidAPIKey: true))
        )
    }
}

#Preview("Missing API Key") {
    withDependencies {
        $0.apiKeyManager = .testNoValidAPIKeyValue
    } operation: {
        WordComparatorMainView(
            store: wordComparatorPreviewStore(for: .init())
        )
    }
}

#Preview("Recent Comparisons") {
    withDependencies {
        $0.apiKeyManager = .testValue
        $0.defaultDatabase = .testDatabase
    } operation: {
        WordComparatorMainView(
            store: wordComparatorPreviewStore(for: .init())
        )
    }
}
#endif
