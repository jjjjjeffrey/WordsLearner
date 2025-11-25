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
                    
                    if !store.backgroundTasks.isEmpty {
                        backgroundTasksQueueView
                    }
                    
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
                        historyButton
                        settingsButton
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
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
            }
        }
        .sheet(
            item: $store.scope(state: \.settings, action: \.settings)
        ) { settingsStore in
            SettingsView(store: settingsStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
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
    
    private var backgroundTasksQueueView: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Background Tasks", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Button {
                    store.send(.clearCompletedTasks)
                } label: {
                    Text("Clear Completed")
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
                }
            }
            
            LazyVStack(spacing: 8) {
                ForEach(store.backgroundTasks) { task in
                    BackgroundTaskRow(
                        task: task,
                        onRemove: {
                            store.send(.removeBackgroundTask(task.id))
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.cardShadow.opacity(0.1), radius: 2, x: 0, y: 1)
        )
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

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = .testDatabase
    }
    
    WordComparatorMainView(
        store: Store(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        }
    )
}

