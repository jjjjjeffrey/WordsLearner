//
//  WordComparatorComposerSheetView.swift
//  WordsLearner
//

import ComposableArchitecture
import SwiftUI

struct WordComparatorComposerSheetView: View {
    @Bindable var store: StoreOf<WordComparatorFeature>
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView

                    if !store.hasValidAPIKey || !store.hasValidElevenLabsAPIKey {
                        apiKeyWarningView
                    }

                    inputFieldsView
                    generateButtonsView
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Word Comparator")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.settingsButtonTapped)
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("AI English Word Comparator")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Compare similar English words with AI assistance")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    private var apiKeyWarningView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("API Keys Required")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            Text("Configure AIHubMix and ElevenLabs API keys in settings to generate text and multimodal lessons.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                store.send(.settingsButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.warning.opacity(0.1))
        )
    }

    private var inputFieldsView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("First Word", systemImage: "1.circle")
                    .font(.headline)

                TextField("Enter first word (e.g., character)", text: $store.word1)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Second Word", systemImage: "2.circle")
                    .font(.headline)

                TextField("Enter second word (e.g., characteristics)", text: $store.word2)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Context Sentence", systemImage: "text.quote")
                    .font(.headline)

                TextField("Paste the sentence here", text: $store.sentence, axis: .vertical)
                    .textFieldStyle(CustomTextFieldStyle())
                    .lineLimit(3...6)
            }
        }
        .padding(.horizontal, 4)
    }

    private var generateButtonsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    store.send(.generateButtonTapped)
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill((store.canGenerate && store.hasValidAPIKey) ? AppColors.primary : AppColors.separator)
                    )
                    .foregroundColor((store.canGenerate && store.hasValidAPIKey) ? .white : .gray)
                }
                .disabled(!store.canGenerate || !store.hasValidAPIKey)

                Button {
                    store.send(.generateInBackgroundButtonTapped)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        #if os(iOS)
                        if horizontalSizeClass == .regular {
                            Text("Background")
                                .fontWeight(.semibold)
                        }
                        #else
                        Text("Background")
                            .fontWeight(.semibold)
                        #endif

                        if store.pendingTasksCount > 0 {
                            Text("(\(store.pendingTasksCount))")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(minWidth: platformButtonWidth())
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill((store.canGenerate && store.hasValidAPIKey) ? AppColors.secondary : AppColors.separator)
                    )
                    .foregroundColor((store.canGenerate && store.hasValidAPIKey) ? .white : .gray)
                }
                .disabled(!store.canGenerate || !store.hasValidAPIKey)
            }

            Button {
                store.send(.generateMultimodalButtonTapped)
            } label: {
                HStack(spacing: 8) {
                    if store.isGeneratingMultimodalLesson {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                    Text(store.isGeneratingMultimodalLesson ? "Generating Multimodal..." : "Generate Multimodal")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canGenerateMultimodal ? AppColors.secondary : AppColors.separator)
                )
                .foregroundColor(canGenerateMultimodal ? .white : .gray)
            }
            .disabled(!canGenerateMultimodal)

            if store.isGeneratingMultimodalLesson {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.multimodalGenerationStatusText ?? "Generating multimodal lesson...")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)

                    if let progress = store.multimodalGenerationProgressFraction {
                        ProgressView(value: progress, total: 1.0)
                            .tint(AppColors.secondary)
                    } else {
                        ProgressView()
                            .tint(AppColors.secondary)
                    }

                    if let stepText = store.multimodalGenerationStepText {
                        Text("Progress: \(stepText)")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.secondaryBackground)
                )
            }
        }
    }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private func platformButtonWidth() -> CGFloat {
        #if os(iOS)
        return 50
        #else
        return 120
        #endif
    }

    private var canGenerateMultimodal: Bool {
        !store.word1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !store.word2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            store.hasValidAPIKey &&
            store.hasValidElevenLabsAPIKey &&
            !store.isGeneratingMultimodalLesson
    }
}
