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
        List {
            if store.filteredComparisons.isEmpty {
                emptyStateSection
            } else {
                ForEach(store.filteredComparisons) { comparison in
                    Button {
                        store.send(.comparisonTapped(comparison))
                    } label: {
                        ComparisonHistoryRow(comparison: comparison)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    store.send(.deleteComparisons(indexSet))
                }
            }
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
    
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: store.searchText.isEmpty ? "tray" : "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text(store.searchText.isEmpty ? "No History Yet" : "No Results Found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if !store.searchText.isEmpty {
                    Text("Try different keywords")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
        .listRowBackground(Color.clear)
    }
    
    private var clearAllButton: some View {
        Button {
            store.send(.clearAllButtonTapped)
        } label: {
            Label("Clear All", systemImage: "trash")
        }
        .disabled(store.allComparisons.isEmpty)
    }
}

// MARK: - Row Component
private struct ComparisonHistoryRow: View {
    let comparison: ComparisonHistory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(comparison.word1)
                    .font(.headline)
                    .foregroundColor(AppColors.word1Color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.word1Background)
                    )
                
                Text("vs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(comparison.word2)
                    .font(.headline)
                    .foregroundColor(AppColors.word2Color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.word2Background)
                    )
                
                Spacer()
            }
            
            Text(comparison.sentence)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(comparison.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
