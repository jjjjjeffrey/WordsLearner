//
//  BackgroundTaskRow.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/25/25.
//
import ComposableArchitecture
import SwiftUI

struct BackgroundTaskRow: View {
    let task: BackgroundTask  // 使用数据库模型
    let onRemove: () -> Void
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                // Status indicator
                statusIcon
                
                // Task info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.word1)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.word1Color)
                        
                        Text("vs")
                            .font(.caption2)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text(task.word2)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.word2Color)
                    }
                    
                    Text(task.sentence)
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                    
                    if let error = task.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(AppColors.error)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Remove button (only for completed or failed tasks)
                if task.taskStatus == .completed || task.taskStatus == .failed {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.secondaryText)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColorForStatus)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(task.taskStatus != .completed)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch task.taskStatus {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(AppColors.secondaryText)
        case .generating:
            ProgressView()
                .scaleEffect(0.8)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(AppColors.error)
        }
    }
    
    private var backgroundColorForStatus: Color {
        switch task.taskStatus {
        case .pending:
            return AppColors.fieldBackground
        case .generating:
            return AppColors.info.opacity(0.1)
        case .completed:
            return AppColors.success.opacity(0.1)
        case .failed:
            return AppColors.error.opacity(0.1)
        }
    }
}
