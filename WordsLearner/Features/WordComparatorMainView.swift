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
    #if os(iOS)
    @State private var splitVisibility: NavigationSplitViewVisibility = .automatic
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .content
    #endif
    
    var body: some View {
        splitView
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(
            item: $store.scope(state: \.settings, action: \.settings)
        ) { settingsStore in
            SettingsView(store: settingsStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var splitView: some View {
        Group {
            #if os(iOS)
            NavigationSplitView(
                columnVisibility: $splitVisibility,
                preferredCompactColumn: $preferredCompactColumn
            ) {
                sidebarView
            } content: {
                contentColumn
            } detail: {
                detailColumn
            }
            #else
            NavigationSplitView {
                sidebarView
            } content: {
                contentColumn
            } detail: {
                detailColumn
            }
            #endif
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: store.detailPresentationToken) { _, _ in
            #if os(iOS)
            guard horizontalSizeClass == .compact else { return }
            preferredCompactColumn = store.detail == nil ? .content : .detail
            #endif
        }
        .onChange(of: store.sidebarSelection) { _, _ in
            #if os(iOS)
            guard horizontalSizeClass == .compact else { return }
            if store.detail == nil {
                preferredCompactColumn = .content
            }
            #endif
        }
        #if os(iOS)
        .onChange(of: preferredCompactColumn) { _, compactColumn in
            guard horizontalSizeClass == .compact else { return }
            if compactColumn != .detail, store.detail != nil {
                store.send(.detailDismissed)
            }
        }
        #endif
    }

    private var sidebarView: some View {
        List(selection: $store.sidebarSelection) {
            ForEach(WordComparatorFeature.SidebarItem.allCases) { item in
                NavigationLink(value: item) {
                    HStack {
                        Label(item.title, systemImage: item.systemImage)
                        Spacer()
                        if item == .backgroundTasks && store.pendingTasksCount > 0 {
                            Text("\(store.pendingTasksCount)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.secondary))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .navigationTitle("WordsLearner")
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
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch store.sidebarSelection ?? .composer {
        case .composer:
            composerContent
        case .history:
            if let historyStore = store.scope(state: \.historyList, action: \.historyList) {
                ComparisonHistoryListView(store: historyStore)
            } else {
                Text("Select History from sidebar")
                    .foregroundStyle(.secondary)
            }
        case .backgroundTasks:
            if let backgroundTasksStore = store.scope(state: \.backgroundTasks, action: \.backgroundTasks) {
                BackgroundTasksView(store: backgroundTasksStore)
            } else {
                Text("Select Background Tasks from sidebar")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let detailStore = store.scope(state: \.detail, action: \.detail) {
            ResponseDetailView(store: detailStore)
        } else {
            ContentUnavailableView(
                "No Comparison Selected",
                systemImage: "text.bubble",
                description: Text("Choose a comparison to view details.")
            )
        }
    }

    private var composerContent: some View {
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
        .background(AppColors.background)
        .navigationTitle("Word Comparator")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
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

#Preview("Empty / Default") {
    withDependencies {
        $0.apiKeyManager = .testValue
    } operation: {
        WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            }
        )
    }
}

#Preview("Ready to Generate") {
    withDependencies {
        $0.apiKeyManager = .testValue
    } operation: {
        WordComparatorMainView(
            store: Store(initialState: .init(word1: "affect", word2: "effect", sentence: "The new policy will affect how the bonus takes effect.", hasValidAPIKey: true)) {
                WordComparatorFeature()
            }
        )
    }
}

#Preview("Missing API Key") {
    withDependencies {
        $0.apiKeyManager = .testNoValidAPIKeyValue
    } operation: {
        WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            }
        )
    }
}

#Preview("Recent Comparisons") {
    withDependencies {
        $0.apiKeyManager = .testValue
        try! $0.bootstrapDatabase()
    } operation: {
        WordComparatorMainView(
            store: Store(initialState: .init()) {
                WordComparatorFeature()
            }
        )
    }
}
#endif
