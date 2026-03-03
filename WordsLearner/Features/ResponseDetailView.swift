//
//  ResponseDetailView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import ComposableArchitecture
import SwiftUI
import AVFoundation
import Combine

struct ResponseDetailView: View {
    @Bindable var store: StoreOf<ResponseDetailFeature>
    @State private var position = ScrollPosition(edge: .top)
    @StateObject private var audioPlayer = ComparisonResponseAudioPlayer()
    @Dependency(\.comparisonAudioAssetStore) private var audioAssetStore

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    comparisonInfoCard
                    audioCard
                    podcastTranscriptCard
                    if shouldShowInlineMarkdown {
                        streamingResponseView
                    } else {
                        markdownNavigationCard
                    }
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
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: store.shouldAutoPlayAfterAudioReady) { _, shouldAutoPlay in
            guard shouldAutoPlay else { return }
            playAudio()
        }
        .onDisappear {
            audioPlayer.stop()
            store.send(.audioPlaybackStopped)
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
                    Button {
                        togglePlayback()
                    } label: {
                        Label(
                            audioPlayer.isPlaying ? "Pause" : "Play",
                            systemImage: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        store.send(.generateAudioButtonTapped)
                    } label: {
                        HStack(spacing: 8) {
                            if store.isGeneratingAudio {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Regenerate")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isGeneratingAudio)

                    Spacer()

                    if let duration = store.audioDurationSeconds {
                        Text(formatDuration(duration))
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
        )
    }

    private var podcastTranscriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Podcast Transcript", systemImage: "text.bubble")
                .font(.headline)

            if !store.podcastTranscript.isEmpty {
                Text(store.podcastTranscript)
                    .textSelection(.enabled)
                    .font(.callout)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.background)
                    )
            }
            else {
                Text("Transcript will appear here after generating audio.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let error = store.podcastTranscriptErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
        )
    }

    private var markdownNavigationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Markdown Analysis", systemImage: "doc.text")
                .font(.headline)
            Text("Markdown analysis is hidden when audio exists.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Open Markdown Detail") {
                store.send(.markdownDetailButtonTapped)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
        )
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

    private var shouldShowInlineMarkdown: Bool {
        store.audioRelativePath == nil
    }

    private func togglePlayback() {
        if audioPlayer.isPlaying {
            audioPlayer.stop()
            store.send(.audioPlaybackStopped)
        } else {
            playAudio()
        }
        store.send(.audioPlaybackToggled)
    }

    private func playAudio() {
        guard let relativePath = store.audioRelativePath else { return }
        guard let data = try? audioAssetStore.loadAudioData(relativePath) else { return }

        store.send(.audioPlaybackToggled)
        audioPlayer.play(data: data) {
            store.send(.audioPlaybackStopped)
        }
    }

    private func formatDuration(_ duration: Double) -> String {
        guard duration.isFinite, duration > 0 else { return "00:00" }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
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

@MainActor
private final class ComparisonResponseAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    private var player: AVAudioPlayer?
    private var completion: (() -> Void)?

    func play(data: Data, completion: @escaping () -> Void) {
        stop()
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            self.player = player
            self.completion = completion
            isPlaying = true
            player.prepareToPlay()
            player.play()
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        completion = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            let completion = self.completion
            stop()
            if flag {
                completion?()
            }
        }
    }
}
