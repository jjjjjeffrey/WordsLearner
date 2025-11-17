//
//  RecentComparisonRow.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//
import SwiftUI

struct RecentComparisonRow: View {
    let comparison: ComparisonHistory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comparison.word1)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.word1Color)
                        
                        Text("vs")
                            .foregroundColor(.secondary)
                        
                        Text(comparison.word2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.word2Color)
                    }
                    
                    Text(comparison.sentence)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(comparison.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.cardBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

