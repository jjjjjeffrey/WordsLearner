//
//  PodcastTranscriptDetailView.swift
//  WordsLearner
//

import ComposableArchitecture
import SwiftUI

struct PodcastTranscriptDetailView: View {
    let store: StoreOf<PodcastTranscriptDetailFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !store.turns.isEmpty {
                    ForEach(Array(store.turns.enumerated()), id: \.offset) { _, turn in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(turn.speaker)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(formatDuration(turn.startSeconds))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fontDesign(.monospaced)
                            }

                            Text(turn.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.secondaryBackground)
                        )
                    }
                } else {
                    Text(store.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .navigationTitle("Podcast Transcript")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(AppColors.background)
    }
}

private func formatDuration(_ seconds: Double) -> String {
    let totalSeconds = max(0, Int(seconds.rounded()))
    let minutes = totalSeconds / 60
    let remainingSeconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
}

#Preview {
    NavigationStack {
        PodcastTranscriptDetailView(
            store: Store(
                initialState: PodcastTranscriptDetailFeature.State(
                    transcript: "Alex (Male): Intro\nMia (Female): Reply",
                    turns: [
                        PodcastTranscriptTurnTiming(
                            speaker: "Alex (Male)",
                            text: "Intro",
                            startSeconds: 0,
                            endSeconds: 4
                        ),
                        PodcastTranscriptTurnTiming(
                            speaker: "Mia (Female)",
                            text: "Reply",
                            startSeconds: 4,
                            endSeconds: 8
                        )
                    ]
                )
            ) {
                PodcastTranscriptDetailFeature()
            }
        )
    }
}
