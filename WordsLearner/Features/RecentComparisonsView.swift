//
//  RecentComparisonsView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/21/25.
//

import ComposableArchitecture
import SwiftUI
import SQLiteData

struct RecentComparisonsView: View {
    @Bindable var store: StoreOf<RecentComparisonsFeature>
    @State private var showingClearAlert = false
    
    var body: some View {
        Group {
            if !store.recentComparisons.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    headerSection
                    comparisonsList
                }
                .padding(.top)
            } else {
                emptyStateView
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert("Clear All Comparisons?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                store.send(.clearAllConfirmed)
            }
        } message: {
            Text("This will delete all comparison history. This action cannot be undone.")
        }
    }
    
    private var headerSection: some View {
        HStack {
            Label("Recent Comparisons", systemImage: "clock.arrow.circlepath")
                .font(.headline)
            
            Spacer()
            
            Menu {
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var comparisonsList: some View {
        LazyVStack(spacing: 8) {
            ForEach(store.recentComparisons) { comparison in
                RecentComparisonRow(comparison: comparison) {
                    store.send(.comparisonTapped(comparison))
                }
            }
            .onDelete { indexSet in
                store.send(.deleteComparisons(indexSet))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Recent Comparisons")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Your comparison history will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = .testDatabase
    }
    
    RecentComparisonsView(
        store: Store(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        }
    )
}
