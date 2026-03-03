//
//  ComparisonPodcastTranscriptClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct ComparisonPodcastTranscriptClient: Sendable {
    var generateTranscript: @Sendable (_ markdown: String) async throws -> String
}

extension ComparisonPodcastTranscriptClient: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.aiService) var aiService

        return Self(
            generateTranscript: { markdown in
                let prompt = """
                Transform the following comparison analysis into a podcast dialogue script.

                Requirements:
                - Two hosts only:
                  - Alex (Male)
                  - Mia (Female)
                - Keep all learning points accurate and exhaustive.
                - You must cover every section from the source, in source order.
                - You must explicitly go through all stories and all example sentences in the source.
                - For example sentences: include each sentence once in the conversation and briefly explain why the target word usage is correct.
                - Do not summarize away details. If the source includes a list, walkthrough, or multiple examples, all of them must appear.
                - Use natural, engaging conversation with occasional light reactions, but prioritize completeness over brevity.
                - Do not use markdown syntax.
                - Output only dialogue lines, each line prefixed by:
                  - Alex (Male):
                  - Mia (Female):
                - Avoid extra narration, titles, or stage directions.
                - End with a short recap that confirms all examples were covered.

                Source analysis:
                \(markdown)
                """

                var transcript = ""
                for try await chunk in aiService.streamResponse(prompt) {
                    transcript += chunk
                }
                return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
    }

    static var previewValue: Self {
        Self(
            generateTranscript: { _ in
                """
                Alex (Male): Let's break this down fast: the two words look similar but they behave differently.
                Mia (Female): Right, and the easiest way is to anchor each one with a clear role and example.
                """
            }
        )
    }

    static var testValue: Self { previewValue }
}

extension DependencyValues {
    var comparisonPodcastTranscript: ComparisonPodcastTranscriptClient {
        get { self[ComparisonPodcastTranscriptClient.self] }
        set { self[ComparisonPodcastTranscriptClient.self] = newValue }
    }
}
