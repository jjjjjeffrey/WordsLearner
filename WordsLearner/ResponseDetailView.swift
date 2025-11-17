//
//  ResponseDetailView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import SwiftUI

struct ResponseDetailView: View {
    @ObservedObject var viewModel: WordComparatorViewModel
    
    var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    headerSection
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                comparisonInfoCard
                                streamingResponseView
                                Spacer(minLength: 100) // Bottom padding
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.streamingResponse) { _ in
                            // Auto-scroll to bottom as content is being streamed
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Comparison Result")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    shareButton
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    shareButton
                }
                #endif
            }
            .onAppear {
                if viewModel.shouldStartStreaming {
                    viewModel.startStreamingComparison()
                }
            }
        }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Words comparison row
            HStack(spacing: 0) {
                // First Word Section
                VStack(spacing: 6) {
                    Text(viewModel.word1)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text("Word 1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
                
                // VS Divider
                VStack {
                    Image(systemName: "arrow.left.and.right")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("vs")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
                .frame(width: 50)
                
                // Second Word Section
                VStack(spacing: 6) {
                    Text(viewModel.word2)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text("Word 2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Progress indicator
            if viewModel.isStreaming {
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating comparison...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal)
            } else {
                // Add some bottom padding when not streaming
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.secondaryBackground)
    }

    
    private var comparisonInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Context Sentence", systemImage: "quote.bubble")
                .font(.headline)
            
            Text(viewModel.sentence)
                .font(.body)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.cardBackground)
                )
        }
    }
    
    private var streamingResponseView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Analysis", systemImage: "brain.head.profile")
                .font(.headline)
            
            if viewModel.streamingResponse.isEmpty && !viewModel.isStreaming {
                ContentUnavailableView(
                    "No Response Yet",
                    systemImage: "text.bubble",
                    description: Text("The AI analysis will appear here")
                )
            } else {
                MarkdownText(viewModel.streamingResponse)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.background)
                            .shadow(color: AppColors.separator.opacity(0.3), radius: 2, x: 0, y: 1)
                    )
            }
            
            // Invisible anchor for auto-scrolling
            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
    }
    
    private var shareButton: some View {
            Button(action: shareComparison) {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(viewModel.streamingResponse.isEmpty)
        }
        
        private func shareComparison() {
            let shareText = """
            Word Comparison: \(viewModel.word1) vs \(viewModel.word2)
            
            Context: \(viewModel.sentence)
            
            Analysis:
            \(viewModel.streamingResponse)
            """
            
            #if os(iOS)
            shareOnIOS(text: shareText)
            #else
            shareOnMacOS(text: shareText)
            #endif
        }
        
        #if os(iOS)
        private func shareOnIOS(text: String) {
            let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
        }
        #endif
        
        #if os(macOS)
        private func shareOnMacOS(text: String) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            
            // 可以选择显示一个通知或者弹窗告诉用户内容已复制
            // 这里我们可以添加一个简单的通知
            DispatchQueue.main.async {
                // 你可以在这里添加一个 toast 通知或者其他反馈
                print("Content copied to clipboard")
            }
        }
        #endif
}


