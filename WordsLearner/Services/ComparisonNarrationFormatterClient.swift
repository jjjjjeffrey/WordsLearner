//
//  ComparisonNarrationFormatterClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct ComparisonNarrationFormatterClient: Sendable {
    var makeNarrationText: @Sendable (_ markdown: String) -> String = { _ in "" }
}

extension ComparisonNarrationFormatterClient: DependencyKey {
    static var liveValue: Self {
        Self(
            makeNarrationText: { markdown in
                formatMarkdownForSpeech(markdown)
            }
        )
    }

    static var previewValue: Self { liveValue }
    static var testValue: Self { liveValue }
}

extension DependencyValues {
    var comparisonNarrationFormatter: ComparisonNarrationFormatterClient {
        get { self[ComparisonNarrationFormatterClient.self] }
        set { self[ComparisonNarrationFormatterClient.self] = newValue }
    }
}

private func formatMarkdownForSpeech(_ markdown: String) -> String {
    var text = markdown

    // Strip fenced code markers while keeping inner text.
    text = text.replacingOccurrences(of: "```", with: "")

    // Convert markdown links [text](url) to text.
    text = text.replacingOccurrences(
        of: #"\[([^\]]+)\]\([^)]+\)"#,
        with: "$1",
        options: .regularExpression
    )

    // Remove inline code and emphasis markers.
    text = text.replacingOccurrences(of: "`", with: "")
    text = text.replacingOccurrences(of: "**", with: "")
    text = text.replacingOccurrences(of: "__", with: "")
    text = text.replacingOccurrences(of: "*", with: "")

    // Remove markdown heading and list prefixes.
    text = text.replacingOccurrences(
        of: #"(?m)^\s*#{1,6}\s*"#,
        with: "",
        options: .regularExpression
    )
    text = text.replacingOccurrences(
        of: #"(?m)^\s*[-+*]\s+"#,
        with: "",
        options: .regularExpression
    )
    text = text.replacingOccurrences(
        of: #"(?m)^\s*\d+\.\s+"#,
        with: "",
        options: .regularExpression
    )

    // Normalize whitespace for a smoother narration flow.
    text = text.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}
