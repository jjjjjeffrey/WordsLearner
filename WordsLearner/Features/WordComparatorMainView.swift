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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
        .sheet(isPresented: $store.isComposerSheetPresented) {
            composerSheet
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
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                newComparisonButton
            }
            #endif
        }
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
                        } else if item == .multimodalLessons && store.isGeneratingMultimodalLesson {
                            if let progress = store.multimodalGenerationProgressFraction {
                                Text("\(Int(progress * 100))%")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AppColors.warning))
                                    .foregroundStyle(.white)
                            } else {
                                ProgressView()
                                    .controlSize(.small)
                            }
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
        switch store.sidebarSelection ?? .history {
        case .history:
            if let historyStore = store.scope(state: \.historyList, action: \.historyList) {
                ComparisonHistoryListView(store: historyStore)
                    #if os(iOS)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            newComparisonIconButton
                        }
                    }
                    #endif
            } else {
                Text("Select History from sidebar")
                    .foregroundStyle(.secondary)
            }
        case .backgroundTasks:
            if let backgroundTasksStore = store.scope(state: \.backgroundTasks, action: \.backgroundTasks) {
                BackgroundTasksView(store: backgroundTasksStore)
                    #if os(iOS)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            newComparisonIconButton
                        }
                    }
                    #endif
            } else {
                Text("Select Background Tasks from sidebar")
                    .foregroundStyle(.secondary)
            }
        case .multimodalLessons:
            if let multimodalStore = store.scope(state: \.multimodalLessons, action: \.multimodalLessons) {
                MultimodalLessonsView(
                    store: multimodalStore,
                    generationStatus: store.multimodalGenerationStatusText,
                    generationProgress: store.multimodalGenerationProgressFraction,
                    generatingLessonID: store.activeMultimodalLessonID
                )
            } else {
                Text("Select Multimodal Lessons from sidebar")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var composerSheet: some View {
        WordComparatorComposerSheetView(store: store) {
            store.isComposerSheetPresented = false
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch store.sidebarSelection ?? .history {
        case .multimodalLessons:
            if let multimodalStore = store.scope(state: \.multimodalLessons, action: \.multimodalLessons) {
                MultimodalLessonDetailView(store: multimodalStore)
                    #if os(iOS)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            newComparisonIconButton
                        }
                    }
                    #endif
            } else {
                ContentUnavailableView(
                    "No Lesson Selected",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Choose a multimodal lesson to view details.")
                )
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        newComparisonIconButton
                    }
                }
                #endif
            }

        case .history, .backgroundTasks:
            if let detailStore = store.scope(state: \.detail, action: \.detail) {
                ResponseDetailView(store: detailStore)
                    #if os(iOS)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            newComparisonIconButton
                        }
                    }
                    #endif
            } else {
                ContentUnavailableView(
                    "No Comparison Selected",
                    systemImage: "text.bubble",
                    description: Text("Choose a comparison to view details.")
                )
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        newComparisonIconButton
                    }
                }
                #endif
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

    private var newComparisonButton: some View {
        Button {
            store.send(.newComparisonButtonTapped)
        } label: {
            Label("New Comparison", systemImage: "plus")
        }
    }

    private var newComparisonIconButton: some View {
        Button {
            store.send(.newComparisonButtonTapped)
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("New Comparison")
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
