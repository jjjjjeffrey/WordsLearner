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
                VStack(alignment: .leading, spacing: 16) {
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
        .background(AppColors.background)
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
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Menu {
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var comparisonsList: some View {
        LazyVStack(spacing: platformSpacing()) {
            ForEach(store.recentComparisons) { comparison in
                SharedComparisonRow(comparison: comparison) {
                    store.send(.comparisonTapped(comparison))
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(AppColors.secondaryText.opacity(0.5))
            
            Text("No Recent Comparisons")
                .font(.headline)
                .foregroundColor(AppColors.secondaryText)
            
            Text("Your comparison history will appear here")
                .font(.caption)
                .foregroundColor(AppColors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func platformSpacing() -> CGFloat {
        #if os(iOS)
        return 12
        #else
        return 8
        #endif
    }
}

#Preview("Not empty") {
    withDependencies {
        try! $0.bootstrapDatabase()
    } operation: {
        RecentComparisonsView(
            store: Store(initialState: RecentComparisonsFeature.State()) {
                RecentComparisonsFeature()
            }
        )
    }
}

#Preview("Empty") {
    RecentComparisonsView(
        store: Store(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        }
    )
}
