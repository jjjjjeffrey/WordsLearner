//
//  ComparisonHistoryListView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/21/25.
//

import ComposableArchitecture
import SwiftUI
import SQLiteData
import UniformTypeIdentifiers

struct ComparisonHistoryListView: View {
    @Bindable var store: StoreOf<ComparisonHistoryListFeature>
    
    var body: some View {
        Group {
            listContent
        }
        .navigationTitle("All Comparisons")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .searchable(text: Binding(
            get: { store.searchText },
            set: { store.send(.textChanged($0)) }
        ), prompt: "Search words or sentence")
        .background(AppColors.background)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                filterButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                clearAllButton
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    importButton
                    exportButton
                    filterButton
                    clearAllButton
                }
            }
            #endif
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        #if os(macOS)
        .fileExporter(
            isPresented: exportIsPresentedBinding,
            document: exportDocumentValue,
            contentType: .json,
            defaultFilename: "comparison_history",
            onCompletion: handleExportCompletion
        )
        .fileImporter(
            isPresented: importIsPresentedBinding,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportCompletion
        )
        #endif
    }
    
    private var listContent: some View {
        Group {
            #if os(iOS)
            iosList
            #else
            macOSScrollView
            #endif
        }
    }
    
    // MARK: - iOS List View
    #if os(iOS)
    private var iosList: some View {
        List {
            if store.filteredComparisons.isEmpty {
                emptyStateSection
            } else {
                ForEach(store.filteredComparisons) { comparison in
                    SharedComparisonRow(comparison: comparison) {
                        store.send(.comparisonTapped(comparison))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .onDelete { indexSet in
                    store.send(.deleteComparisons(indexSet))
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    #endif
    
    // MARK: - macOS Scroll View
    #if os(macOS)
    private var macOSScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if store.filteredComparisons.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    ForEach(store.filteredComparisons) { comparison in
                        SharedComparisonRow(comparison: comparison) {
                            store.send(.comparisonTapped(comparison))
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                if let index = store.filteredComparisons.firstIndex(where: { $0.id == comparison.id }) {
                                    store.send(.deleteComparisons(IndexSet(integer: index)))
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    #endif
    
    // MARK: - Shared Components
    private var emptyStateSection: some View {
        Section {
            emptyStateView
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
        }
        .listRowBackground(Color.clear)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: store.searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(AppColors.secondaryText.opacity(0.5))
            
            Text(store.searchText.isEmpty ? "No History Yet" : "No Results Found")
                .font(.headline)
                .foregroundColor(AppColors.secondaryText)
            
            if !store.searchText.isEmpty {
                Text("Try different keywords")
                    .font(.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
    }
    
    private var filterButton: some View {
        Button {
            store.send(.filterToggled)
        } label: {
            Label(
                store.showUnreadOnly ? "Show All" : "Unread Only",
                systemImage: store.showUnreadOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
            )
        }
    }
    
    private var clearAllButton: some View {
        Button {
            store.send(.clearAllButtonTapped)
        } label: {
            Label("Clear All", systemImage: "trash")
                .foregroundColor(AppColors.error)
        }
        .disabled(store.allComparisons.isEmpty)
    }
    
    #if os(macOS)
    private var exportIsPresentedBinding: Binding<Bool> {
        Binding(
            get: { store.isExporting },
            set: { store.send(.exportPresentationChanged($0)) }
        )
    }
    
    private var importIsPresentedBinding: Binding<Bool> {
        Binding(
            get: { store.isImporting },
            set: { store.send(.importPresentationChanged($0)) }
        )
    }
    
    private var exportDocumentValue: ComparisonHistoryExportDocument? {
        store.exportDocument
    }
    
    private func handleExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            store.send(.exportFinished(nil))
        case let .failure(error):
            store.send(.exportFinished(error.localizedDescription))
        }
    }
    
    private func handleImportCompletion(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            store.send(.importFilePicked(urls))
        case let .failure(error):
            store.send(.importFailed(error.localizedDescription))
        }
    }
    
    private var exportButton: some View {
        Button {
            store.send(.exportButtonTapped)
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(store.allComparisons.isEmpty)
    }
    
    private var importButton: some View {
        Button {
            store.send(.importButtonTapped)
        } label: {
            Label("Import", systemImage: "square.and.arrow.down")
        }
    }
    #endif
}

#Preview("Not empty") {
    withDependencies {
        try! $0.bootstrapDatabase(
            useTest: true,
            seed: { db in
                try db.seed {
                    ComparisonHistory(
                        id: UUID(),
                        word1: "accept",
                        word2: "except",
                        sentence: "I accept all terms.",
                        response: "Use 'accept' for receive/agree, 'except' for excluding.",
                        date: Date().addingTimeInterval(-3600),
                        isRead: false
                    )
                    ComparisonHistory(
                        id: UUID(),
                        word1: "affect",
                        word2: "effect",
                        sentence: "How does this affect the result?",
                        response: "'Affect' is usually a verb; 'effect' is usually a noun.",
                        date: Date(),
                        isRead: true
                    )
                }
            }
        )
    } operation: {
        NavigationStack {
            ComparisonHistoryListView(
                store: Store(initialState: ComparisonHistoryListFeature.State()) {
                    ComparisonHistoryListFeature()
                }
            )
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        ComparisonHistoryListView(
            store: Store(initialState: ComparisonHistoryListFeature.State()) {
                ComparisonHistoryListFeature()
            }
        )
    }
}
