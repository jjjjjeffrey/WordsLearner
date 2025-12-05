//
//  SharedComparisonRow.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/24/25.
//

import SwiftUI

struct SharedComparisonRow: View {
    let comparison: ComparisonHistory
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Word comparison section
                VStack(alignment: .leading, spacing: 8) {
                    // Words row
                    HStack(spacing: 8) {
                        Text(comparison.word1)


                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.word1Color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppColors.word1Background)
                            )
                        
                        Text("vs")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text(comparison.word2)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.word2Color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppColors.word2Background)
                            )
                        
                        Spacer()
                    }
                    
                    // Sentence
                    Text(comparison.sentence)
                        .font(platformFont(.body, fallback: .subheadline))
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Date
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text(comparison.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                }
                
                // Unread badge and chevron
                HStack(spacing: 6) {
                    if !comparison.isRead {
                        Circle()
                            .fill(AppColors.error)
                            .frame(width: 8, height: 8)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .opacity(0.6)
                }
            }
            .padding(platformPadding())
            .background(
                RoundedRectangle(cornerRadius: platformCornerRadius())
                    .fill(backgroundColorForState())
                    .shadow(
                        color: AppColors.cardShadow.opacity(shadowOpacity()),
                        radius: shadowRadius(),
                        x: 0,
                        y: shadowOffset()
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: platformCornerRadius())
                    .stroke(AppColors.separator.opacity(borderOpacity()), lineWidth: borderWidth())
            )
        }
        .buttonStyle(PlainButtonStyle())
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        #endif
    }
    
    // MARK: - Platform-specific helpers
    
    private func platformFont(_ ios: Font, fallback: Font) -> Font {
        #if os(iOS)
        return ios
        #else
        return fallback
        #endif
    }
    
    private func platformPadding() -> EdgeInsets {
        #if os(iOS)
        return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        #else
        return EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        #endif
    }
    
    private func platformCornerRadius() -> CGFloat {
        #if os(iOS)
        return 12
        #else
        return 8
        #endif
    }
    
    private func backgroundColorForState() -> Color {
        #if os(iOS)
        return

 AppColors.dynamicCardBackground
        #else
        return isHovering ? AppColors.hoverBackground : AppColors.dynamicCardBackground
        #endif
    }
    
    private func shadowOpacity() -> Double {
        #if os(iOS)
        return 0.1
        #else
        return isHovering ? 0.2 : 0.05
        #endif
    }
    
    private func shadowRadius() -> CGFloat {
        #if os(iOS)
        return 2
        #else
        return isHovering ? 4 : 1
        #endif
    }
    
    private func shadowOffset() -> CGFloat {
        #if os(iOS)
        return 1
        #else
        return isHovering ? 2 : 0.5
        #endif
    }
    
    private func borderOpacity() -> Double {
        #if os(iOS)
        return 0.1
        #else
        return 0.2
        #endif
    }
    
    private func borderWidth() -> CGFloat {
        #if os(iOS)
        return 0
        #else
        return 0.5
        #endif
    }
}

#Preview {
    let sampleComparison = ComparisonHistory(
        id: UUID(),
        word1: "character",
        word2: "characteristic",
        sentence: "The character of this wine is unique and shows the winery's attention to detail.",
        response: "Sample response",
        date: Date(),
        isRead: false
    )
    
    VStack(spacing: 8) {
        SharedComparisonRow(
            comparison: ComparisonHistory(
                id: UUID(),
                word1: sampleComparison.word1,
                word2: sampleComparison.word2,
                sentence: sampleComparison.sentence,
                response: sampleComparison.response,
                date: sampleComparison.date,
                isRead: false
            )
        ) {
            print("Tapped")
        }
        
        SharedComparisonRow(
            comparison: ComparisonHistory(
                id: UUID(),
                word1: "affect",
                word2: "effect",
                sentence: "How does this change affect the final result?",
                response: "Another response",
                date: Date().addingTimeInterval(-3600),
                isRead: true
            )
        ) {
            print("Tapped 2")
        }
    }
    .padding()
}
