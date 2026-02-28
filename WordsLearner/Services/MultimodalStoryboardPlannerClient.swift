//
//  MultimodalStoryboardPlannerClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

struct StoryboardPlan: Codable, Equatable, Sendable {
    let schemaVersion: String
    let lessonObjective: String
    let styleConsistency: String?
    let stories: [StoryboardStoryPlan]
    let finalConclusion: StoryboardFinalConclusionPlan
}

struct StoryboardStoryPlan: Codable, Equatable, Sendable {
    let storyID: String
    let focusWord: String
    let title: String
    let meaningSummary: String
    let frames: [StoryboardFramePlan]
}

struct StoryboardFramePlan: Codable, Equatable, Sendable {
    let indexInStory: Int
    let globalIndex: Int
    let role: String
    let targetWord: String
    let title: String
    let caption: String
    let narrationText: String
    let imagePrompt: String
    let checkPrompt: String?
    let expectedAnswer: String?
}

enum StoryboardConclusionVerdict: String, Codable, Equatable, Sendable {
    case yes
    case no
    case depends
}

struct StoryboardFinalConclusionPlan: Codable, Equatable, Sendable {
    let verdict: StoryboardConclusionVerdict
    let verdictReason: String
    let sentenceFromUser: String
    let recommendedUsage: String
    let toneDifferenceNote: String
    let narrationText: String
    let imagePrompt: String
}

enum StoryboardValidationError: LocalizedError {
    case storyCount(Int)
    case frameCount(storyID: String, count: Int)
    case missingRoles(storyID: String)
    case indexMismatch(storyID: String)
    case duplicateGlobalIndex(Int)
    case globalIndexSequence
    case duplicateStoryMeaning
    case emptyConclusionNarration
    case emptyConclusionUsage
    case missingSentenceConclusion

    var errorDescription: String? {
        switch self {
        case let .storyCount(count):
            return "Storyboard requires at least 2 stories, got \(count)."
        case let .frameCount(storyID, count):
            return "Storyboard story '\(storyID)' requires 4 frames, got \(count)."
        case let .missingRoles(storyID):
            return "Storyboard story '\(storyID)' is missing required frame roles."
        case let .indexMismatch(storyID):
            return "Storyboard story '\(storyID)' has invalid frame indexes."
        case let .duplicateGlobalIndex(index):
            return "Storyboard has duplicate global frame index: \(index)."
        case .globalIndexSequence:
            return "Storyboard global frame indexes must be contiguous from 0."
        case .duplicateStoryMeaning:
            return "Storyboard stories are semantically duplicate."
        case .emptyConclusionNarration:
            return "Storyboard final conclusion narration is empty."
        case .emptyConclusionUsage:
            return "Storyboard final conclusion usage recommendation is empty."
        case .missingSentenceConclusion:
            return "Storyboard final conclusion does not reference the user sentence."
        }
    }
}

@DependencyClient
struct MultimodalStoryboardPlannerClient: Sendable {
    var plan: @Sendable (_ word1: String, _ word2: String, _ sentence: String?) async throws -> StoryboardPlan
}

extension MultimodalStoryboardPlannerClient: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.aiService) var aiService
        return Self(
            plan: { word1, word2, sentence in
                var lastError: Error?
                for attempt in 1...3 {
                    let prompt = buildPrompt(
                        word1: word1,
                        word2: word2,
                        sentence: sentence,
                        attempt: attempt,
                        previousError: lastError
                    )

                    var response = ""
                    do {
                        for try await chunk in aiService.streamResponse(prompt) {
                            response += chunk
                        }

                        let cleaned = response
                            .replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        let data = Data(cleaned.utf8)
                        let plan = try JSONDecoder().decode(StoryboardPlan.self, from: data)
                        try validate(plan, sourceSentence: sentence)
                        return plan
                    } catch {
                        lastError = error
                    }
                }

                throw lastError ?? StoryboardValidationError.storyCount(0)
            }
        )
    }

    static var previewValue: Self {
        Self(
            plan: { word1, word2, sentence in
                StoryboardPlan(
                    schemaVersion: "v2.0",
                    lessonObjective: "Build certainty about when to use each word in real communication.",
                    styleConsistency: "Story-first, certainty-first multimodal lesson with concrete mini-stories.",
                    stories: [
                        StoryboardStoryPlan(
                            storyID: "story_a",
                            focusWord: word1,
                            title: "\(word1) in action",
                            meaningSummary: "A concrete situation where \(word1) is the natural choice.",
                            frames: [
                                StoryboardFramePlan(
                                    indexInStory: 0,
                                    globalIndex: 0,
                                    role: "setup",
                                    targetWord: word1,
                                    title: "Setup",
                                    caption: "A clear context introduces the problem.",
                                    narrationText: "A student faces a moment where choosing the right word matters.",
                                    imagePrompt: "Cinematic storyboard frame, landscape 16:9, classroom scene with clear context and no text.",
                                    checkPrompt: nil,
                                    expectedAnswer: nil
                                ),
                                StoryboardFramePlan(
                                    indexInStory: 1,
                                    globalIndex: 1,
                                    role: "conflict",
                                    targetWord: word1,
                                    title: "Conflict",
                                    caption: "Only \(word1) sounds natural in this moment.",
                                    narrationText: "The wrong choice would sound odd here. \(word1) fits the action and intention.",
                                    imagePrompt: "Cinematic storyboard frame, landscape 16:9, same characters in a tense moment, no text.",
                                    checkPrompt: "Which word fits better?",
                                    expectedAnswer: word1
                                ),
                                StoryboardFramePlan(
                                    indexInStory: 2,
                                    globalIndex: 2,
                                    role: "outcome",
                                    targetWord: word1,
                                    title: "Outcome",
                                    caption: "The result confirms the intended meaning.",
                                    narrationText: "The outcome makes the meaning of \(word1) obvious and memorable.",
                                    imagePrompt: "Cinematic storyboard frame, landscape 16:9, consequence-focused scene, no text.",
                                    checkPrompt: nil,
                                    expectedAnswer: nil
                                ),
                                StoryboardFramePlan(
                                    indexInStory: 3,
                                    globalIndex: 3,
                                    role: "language_lock_in",
                                    targetWord: word1,
                                    title: "Language Lock-In",
                                    caption: "In this story, \(word1) is the right fit.",
                                    narrationText: "In this story, the character clearly uses \(word1) for this specific meaning.",
                                    imagePrompt: "Cinematic storyboard frame, landscape 16:9, reflective closing shot, no text.",
                                    checkPrompt: "Why does \(word1) fit here?",
                                    expectedAnswer: "Because the context matches its meaning."
                                )
                            ]
                        ),
                        StoryboardStoryPlan(
                            storyID: "story_b",
                            focusWord: word2,
                            title: "\(word2) in action",
                            meaningSummary: "A separate context where \(word2) is the natural choice.",
                            frames: [
                                StoryboardFramePlan(
                                    indexInStory: 0,
                                    globalIndex: 4,
                                    role: "setup",
                                    targetWord: word2,
                                    title: "Setup",
                                    caption: "A different context introduces a new usage challenge.",
                                    narrationText: "In a new situation, the learner must choose between \(word1) and \(word2).",
                                    imagePrompt: "Cinematic storyboard frame, landscape 16:9, different setting and characters, no text.",
                                    checkPrompt: nil,
                                    expectedAnswer: nil
                                ),
                                StoryboardFramePlan(
                                    indexInStory: 1,
                                    globalIndex: 5,
                                    role: "conflict",
                                    targetWord: word2,
                                    title: "Conflict",
                                    caption: "Only \(word2) feels natural here.",
                                    narrationText: "Now \(word2) is the only smooth choice in this specific context.",
                                    imagePrompt: "Cinematic storyboard frame, landscape 16:9, situational tension in a real-life moment, no text.",
                                    checkPrompt: "Which word is natural now?",
                                    expectedAnswer: word2
                                ),
                                StoryboardFramePlan(
                                    indexInStory: 2,
                                    globalIndex: 6,
                                    role: "outcome",
                                    targetWord: word2,
                                    title: "Outcome",
                                    caption: "The consequence highlights the contrast.",
                                    narrationText: "The result shows why \(word2) carries a different meaning from \(word1).",
                                    imagePrompt: "Cinematic storyboard frame, landscape 16:9, clear consequence scene, no text.",
                                    checkPrompt: nil,
                                    expectedAnswer: nil
                                ),
                                StoryboardFramePlan(
                                    indexInStory: 3,
                                    globalIndex: 7,
                                    role: "language_lock_in",
                                    targetWord: word2,
                                    title: "Language Lock-In",
                                    caption: "In this story, \(word2) is the right fit.",
                                    narrationText: "In this story, the character clearly uses \(word2) in the natural way.",
                                    imagePrompt: "Cinematic storyboard frame, landscape 16:9, closing scene with emotional clarity, no text.",
                                    checkPrompt: "Can \(word1) replace \(word2) here?",
                                    expectedAnswer: "No"
                                )
                            ]
                        )
                    ],
                    finalConclusion: StoryboardFinalConclusionPlan(
                        verdict: .depends,
                        verdictReason: "They overlap in some contexts but differ in intent and tone.",
                        sentenceFromUser: sentence ?? "",
                        recommendedUsage: "Use the word that matches the sentence's intent and emotional tone.",
                        toneDifferenceNote: "\(word1) can feel stronger or more emotional depending on context; \(word2) can feel more neutral in structural constraints.",
                        narrationText: "Final verdict: it depends on your sentence context. Choose the word that matches your intended meaning and tone.",
                        imagePrompt: "Cinematic storyboard frame, landscape 16:9, final summary scene with two paths converging, no text."
                    )
                )
            }
        )
    }

    static var testValue: Self {
        previewValue
    }
}

private func buildPrompt(
    word1: String,
    word2: String,
    sentence: String?,
    attempt: Int,
    previousError: Error?
) -> String {
    let retryInstruction: String
    if attempt == 1 {
        retryInstruction = ""
    } else {
        retryInstruction = """

        Retry note:
        - Your previous output failed validation.
        - Fix schema and constraints exactly.
        - Validation failure hint: \(previousError?.localizedDescription ?? "unknown")
        """
    }

    return """
    Return ONLY valid JSON, no markdown fences.
    Build a multimodal lesson in story style for English word comparison.
    Follow this teaching style strictly:
    - Tell concrete mini-stories with named characters and everyday scenes.
    - Write at elementary third-grade level: very simple words, short sentences, no slang.
    - Make meaning obvious through situation + consequence (show, then explain).
    - Start story narration in an "imagine this scene" voice when natural.
    - Use explicit lock-in phrasing such as "In this story, ...".
    - End with a clear interchangeability verdict for the user's sentence.

    Input:
    word1: \(word1)
    word2: \(word2)
    userSentence: \(sentence ?? "")

    Required output:
    - At least 2 distinct stories (`story_a`, `story_b`), each exactly 4 frames.
    - Story A must primarily show usage for word1.
    - Story B must primarily show usage for word2.
    - Frame roles per story exactly once: setup, conflict, outcome, language_lock_in.
    - Global frame indexes must be contiguous from 0.
    - Each frame narration must be 2-4 short spoken sentences.
    - Story narration should feel sequential: setup -> conflict -> outcome -> language lock-in.
    - Image prompts: cinematic storyboard, landscape 16:9, no text/letters/watermarks.
    - Never make Story B a paraphrase clone of Story A.
    - At least one story should connect to the user sentence context when possible.

    Final conclusion:
    - Provide verdict: yes/no/depends for interchangeability in user sentence.
    - Include a short reason, recommended usage, and tone difference note.
    - Include conclusion narration text for audio playback, in simple spoken English.

    JSON schema:
    {
      "schemaVersion": "v2.0",
      "lessonObjective": "string",
      "styleConsistency": "string",
      "stories": [
        {
          "storyID": "story_a|story_b|story_c",
          "focusWord": "word1|word2|both",
          "title": "string",
          "meaningSummary": "string",
          "frames": [
            {
              "indexInStory": 0,
              "globalIndex": 0,
              "role": "setup|conflict|outcome|language_lock_in",
              "targetWord": "word1|word2|both|contrast",
              "title": "string",
              "caption": "string",
              "narrationText": "spoken narration",
              "imagePrompt": "cinematic visual prompt, 16:9, no text",
              "checkPrompt": "string or null",
              "expectedAnswer": "string or null"
            }
          ]
        }
      ],
      "finalConclusion": {
        "verdict": "yes|no|depends",
        "verdictReason": "string",
        "sentenceFromUser": "string",
        "recommendedUsage": "string",
        "toneDifferenceNote": "string",
        "narrationText": "string",
        "imagePrompt": "cinematic visual prompt, 16:9, no text"
      }
    }
    \(retryInstruction)
    """
}

private func validate(_ plan: StoryboardPlan, sourceSentence: String?) throws {
    guard plan.stories.count >= 2 else {
        throw StoryboardValidationError.storyCount(plan.stories.count)
    }

    let requiredRoles: Set<String> = ["setup", "conflict", "outcome", "language_lock_in"]
    var globalIndexes = Set<Int>()
    var storyFingerprints = Set<String>()

    for story in plan.stories {
        guard story.frames.count == 4 else {
            throw StoryboardValidationError.frameCount(storyID: story.storyID, count: story.frames.count)
        }

        let roles = Set(story.frames.map(\.role))
        guard roles == requiredRoles else {
            throw StoryboardValidationError.missingRoles(storyID: story.storyID)
        }

        let storyIndexes = story.frames.map(\.indexInStory).sorted()
        guard storyIndexes == [0, 1, 2, 3] else {
            throw StoryboardValidationError.indexMismatch(storyID: story.storyID)
        }

        for frame in story.frames {
            guard globalIndexes.insert(frame.globalIndex).inserted else {
                throw StoryboardValidationError.duplicateGlobalIndex(frame.globalIndex)
            }
            if frame.role == "language_lock_in" &&
                !frame.narrationText.localizedLowercase.contains("in this story") {
                throw StoryboardValidationError.missingRoles(storyID: story.storyID)
            }
        }

        let combined = "\(story.title.lowercased())|\(story.meaningSummary.lowercased())|\(story.frames.map(\.caption).joined(separator: " ").lowercased())"
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        storyFingerprints.insert(combined)
    }

    guard storyFingerprints.count == plan.stories.count else {
        throw StoryboardValidationError.duplicateStoryMeaning
    }

    let sortedGlobal = globalIndexes.sorted()
    let expected = Array(0..<sortedGlobal.count)
    guard sortedGlobal == expected else {
        throw StoryboardValidationError.globalIndexSequence
    }

    guard !plan.finalConclusion.narrationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw StoryboardValidationError.emptyConclusionNarration
    }
    guard !plan.finalConclusion.recommendedUsage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw StoryboardValidationError.emptyConclusionUsage
    }

    if let sourceSentence, !sourceSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        guard !plan.finalConclusion.sentenceFromUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoryboardValidationError.missingSentenceConclusion
        }
    }
}

extension DependencyValues {
    var multimodalStoryboardPlanner: MultimodalStoryboardPlannerClient {
        get { self[MultimodalStoryboardPlannerClient.self] }
        set { self[MultimodalStoryboardPlannerClient.self] = newValue }
    }
}
