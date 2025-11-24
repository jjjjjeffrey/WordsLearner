//
//  ComparisonHistoryListView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/21/25.
//

import ComposableArchitecture
import SwiftUI
import SQLiteData

struct ComparisonHistoryListView: View {
    @Bindable var store: StoreOf<ComparisonHistoryListFeature>
    
    var body: some View {
        Group {
            #if os(iOS)
            iosList
            #else
            macOSScrollView
            #endif
        }
        .navigationTitle("All Comparisons")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .searchable(text: $store.searchText.sending(\.textChanged), prompt: "Search words or sentence")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                clearAllButton
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                clearAllButton
            }
            #endif
        }
        .alert($store.scope(state: \.alert, action: \.alert))
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
                .padding(.vertical, 60

)
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
    
    private var clearAllButton: some View {
        Button {
            store.send(.clearAllButtonTapped)
        } label: {
            Label("Clear All", systemImage: "trash")
                .foregroundColor(AppColors.error)
        }
        .disabled(store.allComparisons.isEmpty)
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = .testDatabase
    }
    
    NavigationStack {
        ComparisonHistoryListView(
            store: Store(initialState: ComparisonHistoryListFeature.State()) {
                ComparisonHistoryListFeature()
            }
        )
    }
}
