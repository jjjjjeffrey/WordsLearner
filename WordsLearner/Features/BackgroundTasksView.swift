//
//  BackgroundTasksView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/26/25.
//

import ComposableArchitecture
import SwiftUI
import SQLiteData

struct BackgroundTasksView: View {
    @Bindable var store: StoreOf<BackgroundTasksFeature>
    @State private var showingClearAlert = false
    
    var body: some View {
        Group {
            if store.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .navigationTitle("Background Tasks")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            toolbarContent
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert("Clear All Tasks?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                store.send(.clearAllTasks)
            }
        } message: {
            Text("This will remove all background tasks including pending ones. This action cannot be undone.")
        }
    }
    
    // MARK: - Task List View
    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: platformSpacing()) {
                // Status summary
                statusSummaryCard
                
                // Task list
                ForEach(store.tasks) { task in
                    BackgroundTaskRow(
                        task: task,
                        onRemove: {
                            store.send(.removeTask(task.id))
                        },
                        onTap: {
                            if task.taskStatus == .completed {
                                // Navigate to view the result
                                let comparison = ComparisonHistory(
                                    id: UUID(), // New ID for history entry
                                    word1: task.word1,
                                    word2: task.word2,
                                    sentence: task.sentence,
                                    response: task.response,
                                    date: task.updatedAt,
                                    isRead: false
                                )
                                store.send(.viewComparisonHistory(comparison))
                            }
                        },
                        onRegenerate: {
                            store.send(.regenerateTask(task.id))
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Status Summary Card
    private var statusSummaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Pending count
                StatusBadge(
                    count: store.pendingTasksCount,
                    label: "Pending",
                    color: AppColors.info,
                    icon: "clock"
                )
                
                // Completed count
                StatusBadge(
                    count: store.completedTasksCount,
                    label: "Completed",
                    color: AppColors.success,
                    icon: "checkmark.circle"
                )
                
                Spacer()
            }
            
            if store.isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    if let currentTask = store.tasks.first(where: { $0.id == store.currentGeneratingTaskId }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Generating comparison...")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                            
                            Text("\(currentTask.word1) vs \(currentTask.word2)")
                                .font(.caption2)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                    } else {
                        Text("Generating comparison...")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
        )
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(AppColors.secondaryText.opacity(0.5))
            
            Text("No Background Tasks")
                .font(.headline)
                .foregroundColor(AppColors.secondaryText)
            
            Text("Tasks you queue for background generation will appear here")
                .font(.caption)
                .foregroundColor(AppColors.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    store.send(.clearCompletedTasks)
                } label: {
                    Label("Clear Completed", systemImage: "checkmark.circle")
                }
                .disabled(store.completedTasksCount == 0)
                
                Divider()
                
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(store.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 8) {
                Button {
                    store.send(.clearCompletedTasks)
                } label: {
                    Label("Clear Completed", systemImage: "checkmark.circle")
                }
                .disabled(store.completedTasksCount == 0)
                
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                        .foregroundColor(AppColors.error)
                }
                .disabled(store.isEmpty)
            }
        }
        #endif
    }
    
    // MARK: - Helper
    private func platformSpacing() -> CGFloat {
        #if os(iOS)
        return 12
        #else
        return 8
        #endif
    }
}

// MARK: - Status Badge Component
struct StatusBadge: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
}

// MARK: - Preview
#Preview("Not empty") {
    withDependencies {
        $0.defaultDatabase = .testDatabase
    } operation: {
        NavigationStack {
            BackgroundTasksView(
                store: Store(
                    initialState: BackgroundTasksFeature.State()
                ) {
                    BackgroundTasksFeature()
                }
            )
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        BackgroundTasksView(
            store: Store(
                initialState: BackgroundTasksFeature.State()
            ) {
                BackgroundTasksFeature()
            }
        )
    }
}


