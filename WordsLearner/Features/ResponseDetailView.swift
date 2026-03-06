//
//  ResponseDetailView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import ComposableArchitecture
import SwiftUI

struct ResponseDetailView: View {
    @Bindable var store: StoreOf<ResponseDetailFeature>
    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    comparisonInfoCard
                    audioCard
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
        .background(AppColors.background)
        .navigationDestination(
            item: $store.scope(state: \.markdownDetail, action: \.markdownDetail)
        ) { markdownStore in
            MarkdownDetailView(store: markdownStore)
        }
        .navigationDestination(
            item: $store.scope(state: \.transcriptDetail, action: \.transcriptDetail)
        ) { transcriptStore in
            PodcastTranscriptDetailView(store: transcriptStore)
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
            } else if shouldShowInlineMarkdown {
                MarkdownText(store.attributedString)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.background)
                            .shadow(color: AppColors.separator.opacity(0.3), radius: 2, x: 0, y: 1)
                    )
            } else {
                Text("Analysis is hidden while the audio experience is active.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    store.send(.markdownDetailButtonTapped)
                } label: {
                    Label("View Full Analysis", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Color.clear.frame(height: 1).id("bottom")
        }
    }

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audio", systemImage: "waveform")
                .font(.headline)

            if !store.podcastTranscript.isEmpty {
                Text("Source: Podcast transcript (male/female voices)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Generate Audio will create podcast transcript first, then audio.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if store.audioRelativePath == nil {
                Button {
                    store.send(.generateAudioButtonTapped)
                } label: {
                    HStack(spacing: 8) {
                        if store.isGeneratingAudio {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(store.isGeneratingAudio ? "Generating Audio..." : "Generate Audio")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canGenerateAudio)
            } else {
                HStack(spacing: 10) {
                    #if os(macOS)
                    Button {
                        store.send(.audioJumpToPreviousTurn)
                    } label: {
                        Label("Previous", systemImage: "backward.end.fill")
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                    .disabled(!canJumpToPreviousTurn)

                    Button {
                        store.send(.audioPlaybackToggled)
                    } label: {
                        Label(
                            store.isAudioPlaying ? "Pause" : "Play",
                            systemImage: store.isAudioPlaying ? "pause.circle.fill" : "play.circle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        store.send(.audioJumpToNextTurn)
                    } label: {
                        Label("Next", systemImage: "forward.end.fill")
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                    .disabled(!canJumpToNextTurn)
                    #else
                    Button {
                        store.send(.audioPlaybackToggled)
                    } label: {
                        Image(systemName: store.isAudioPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(store.isAudioPlaying ? "Pause" : "Play")
                    #endif

                    Button {
                        store.send(.audioPlaybackStopped)
                        store.send(.generateAudioButtonTapped)
                    } label: {
                        #if os(iOS)
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                        #else
                        HStack(spacing: 8) {
                            if store.isGeneratingAudio {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Regenerate")
                        }
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isGeneratingAudio)
                    #if os(iOS)
                    .accessibilityLabel("Regenerate")
                    #endif

                    Spacer()

                    if let duration = store.audioDurationSeconds {
                        Text(audioTimeStatus(duration: duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontDesign(.monospaced)
                    }
                }
            }

            if store.isGeneratingAudio {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: store.audioGenerationProgress, total: 1.0)
                        .progressViewStyle(.linear)
                    if let status = store.audioGenerationStatusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let audioError = store.audioErrorMessage {
                Text(audioError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if canShowTranscriptDetail {
                Button {
                    store.send(.transcriptDetailButtonTapped)
                } label: {
                    Label("View Full Transcript", systemImage: "text.document")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if let activeTurnIndex = store.currentSpeakerTurnIndex {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.isAudioPlaying ? "Now Speaking" : "Paused At")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    transcriptFocusCard(activeTurnIndex: activeTurnIndex)
                }
            } else if let currentTurnText = store.currentSpeakerTurnText {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.isAudioPlaying ? "Now Speaking" : "Paused At")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentTurnText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
        )
    }

    @ViewBuilder
    private func transcriptFocusCard(activeTurnIndex: Int) -> some View {
        let turns = store.transcriptTurnTimings
        let previousTurn = activeTurnIndex > 0 ? turns[activeTurnIndex - 1] : nil
        let currentTurn = turns.indices.contains(activeTurnIndex) ? turns[activeTurnIndex] : nil
        let nextTurn = turns.indices.contains(activeTurnIndex + 1) ? turns[activeTurnIndex + 1] : nil

        VStack(alignment: .leading, spacing: 10) {
            if let previousTurn {
                transcriptTurnRow(
                    turn: previousTurn,
                    emphasis: .context,
                    label: "Previous",
                    isJumpEnabled: true
                ) {
                    store.send(.audioJumpToTurn(activeTurnIndex - 1))
                }
            }
            if let currentTurn {
                transcriptTurnRow(
                    turn: currentTurn,
                    emphasis: .current,
                    label: store.isAudioPlaying ? "Current" : "Paused Here",
                    isJumpEnabled: false,
                    action: nil
                )
            }
            if let nextTurn {
                transcriptTurnRow(
                    turn: nextTurn,
                    emphasis: .context,
                    label: "Next",
                    isJumpEnabled: true
                ) {
                    store.send(.audioJumpToTurn(activeTurnIndex + 1))
                }
            }
        }
    }

    @ViewBuilder
    private func transcriptTurnRow(
        turn: PodcastTranscriptTurnTiming,
        emphasis: TranscriptTurnEmphasis,
        label: String,
        isJumpEnabled: Bool,
        action: (() -> Void)?
    ) -> some View {
        let content = HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 999)
                .fill(emphasis == .current ? Color.accentColor : AppColors.separator.opacity(0.6))
                .frame(width: emphasis == .current ? 5 : 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(emphasis == .current ? .accentColor : .secondary)

                HStack(spacing: 6) {
                    Text(turn.speaker)
                        .font(emphasis == .current ? .subheadline : .caption)
                        .fontWeight(.semibold)
                        .foregroundColor(emphasis == .current ? .primary : .secondary)

                    if isJumpEnabled {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Text(turn.text)
                    .font(emphasis == .current ? .title3 : .callout)
                    .fontWeight(emphasis == .current ? .semibold : .regular)
                    .lineSpacing(emphasis == .current ? 3 : 1)
                    .foregroundColor(emphasis == .current ? .primary : .secondary)
                    .lineLimit(emphasis == .current ? nil : 2)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(emphasis == .current ? 12 : 10)
        .background(
            RoundedRectangle(cornerRadius: emphasis == .current ? 12 : 10)
                .fill(emphasis == .current ? Color.accentColor.opacity(0.12) : AppColors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: emphasis == .current ? 12 : 10)
                .stroke(
                    emphasis == .current ? Color.accentColor.opacity(0.35) : AppColors.separator.opacity(0.2),
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: emphasis == .current ? 12 : 10))

        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
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

    private var canGenerateAudio: Bool {
        store.comparisonID != nil
            && !store.streamingResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.isGeneratingAudio
    }

    private var canShowTranscriptDetail: Bool {
        !store.podcastTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !store.transcriptTurnTimings.isEmpty
    }

    private var shouldShowInlineMarkdown: Bool {
        store.audioRelativePath == nil
    }

    private var canJumpToPreviousTurn: Bool {
        guard let activeTurnIndex = store.currentSpeakerTurnIndex else { return false }
        return activeTurnIndex > 0
    }

    private var canJumpToNextTurn: Bool {
        guard let activeTurnIndex = store.currentSpeakerTurnIndex else { return false }
        return activeTurnIndex + 1 < store.transcriptTurnTimings.count
    }

    private func formatDuration(_ duration: Double) -> String {
        guard duration.isFinite, duration > 0 else { return "00:00" }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func audioTimeStatus(duration: Double) -> String {
        let clampedCurrent = min(max(store.currentAudioTimeSeconds, 0), duration)
        return "\(formatDuration(clampedCurrent)) / \(formatDuration(duration))"
    }
}

private enum TranscriptTurnEmphasis {
    case context
    case current
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
