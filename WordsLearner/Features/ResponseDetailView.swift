//
//  ResponseDetailView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import ComposableArchitecture
import SwiftUI

struct ResponseDetailView: View {
    let store: StoreOf<ResponseDetailFeature>
    @State private var position = ScrollPosition(edge: .top)
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    comparisonInfoCard
                    streamingResponseView
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .scrollPosition($position)
            .onChange(of: store.scrollToBottomId) { _, _ in
                position.scrollTo(edge: .bottom)
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
            store.send(.onAppear)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(store.word1)
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
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
                
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
                
                VStack(spacing: 6) {
                    Text(store.word2)
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
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
            }
            .padding(.horizontal)
            .padding(.top)
            
            if store.isStreaming {
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Generating comparison...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal)
            } else {
                Rectangle().fill(Color.clear).frame(height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.secondaryBackground)
    }
    
    private var comparisonInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Context Sentence", systemImage: "quote.bubble")
                .font(.headline)
            
            Text(store.sentence)
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
            
            if store.attributedString.characters.isEmpty && !store.isStreaming {
                ContentUnavailableView(
                    "No Response Yet",
                    systemImage: "text.bubble",
                    description: Text("The AI analysis will appear here")
                )
            } else {
                MarkdownText(store.attributedString)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.background)
                            .shadow(color: AppColors.separator.opacity(0.3), radius: 2, x: 0, y: 1)
                    )
            }
            
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Color.clear.frame(height: 1).id("bottom")
        }
    }
    
    private var shareButton: some View {
        Button {
            store.send(.shareButtonTapped)
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(store.streamingResponse.isEmpty)
    }
}

#Preview {
    withDependencies {
        $0.comparisonGenerator = .previewValue
    } operation: {
        NavigationStack {
            ResponseDetailView(
                store: Store(
                    initialState: ResponseDetailFeature.State(
                        word1: "character",
                        word2: "characteristic",
                        sentence: "This is a test sentence."
                    )
                ) {
                    ResponseDetailFeature()
                }
            )
            #if os(macOS)
            .frame(minWidth: 900, idealWidth: 1000, maxWidth: 1200, minHeight: 560, idealHeight: 800, maxHeight: .infinity)
            .padding(32)
            #endif
        }
    }
}



