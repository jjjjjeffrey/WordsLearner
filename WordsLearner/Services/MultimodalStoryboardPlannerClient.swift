//
//  MultimodalStoryboardPlannerClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

struct StoryboardPlan: Codable, Equatable, Sendable {
    let schemaVersion: String
    let lessonObjective: String
    let styleConsistency: String
    let frames: [StoryboardFramePlan]
}

struct StoryboardFramePlan: Codable, Equatable, Sendable {
    let index: Int
    let role: String
    let targetWord: String
    let title: String
    let caption: String
    let narrationText: String
    let imagePrompt: String
    let checkPrompt: String?
    let expectedAnswer: String?
}

enum StoryboardValidationError: LocalizedError {
    case frameCount(Int)
    case missingRoles

    var errorDescription: String? {
        switch self {
        case let .frameCount(count):
            return "Storyboard requires 4 frames, got \(count)."
        case .missingRoles:
            return "Storyboard is missing required frame roles."
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
                let prompt = """
                Return ONLY valid JSON, no markdown fences.
                Generate a 4-frame storyboard for English vocabulary contrast learning.

                Teaching principles you must follow:
                - Main goal: help the learner feel CERTAIN about when to use each word.
                - Each frame must remove one specific doubt (not just give definitions).
                - Use one connected mini-story with the same characters and world.
                - Create an "aha" progression: confusion -> contrast -> resolution.
                - Use naturally varied context, not repetitive textbook sentences.

                Required roles exactly once:
                - word1_only
                - word2_only
                - overlap
                - non_interchangeable

                Input:
                word1: \(word1)
                word2: \(word2)
                userSentence: \(sentence ?? "")

                Output constraints:
                - Exactly 4 frames with indexes 0,1,2,3.
                - English level: simple, spoken, clear (roughly A2-B1).
                - narrationText: 2-4 short spoken sentences, concrete and vivid.
                - imagePrompt: visually rich scene direction, not dictionary style.
                - imagePrompt must request a cinematic storyboard frame in landscape 16:9.
                - Never put words, subtitles, labels, or letters inside the image.

                Frame intent:
                - word1_only: context where only word1 is natural.
                - word2_only: context where only word2 is natural.
                - overlap: both can be used but with nuance/tone difference.
                - non_interchangeable: show wrong swap and immediate correction.
                - Use userSentence as inspiration in at least one frame when possible.

                JSON schema:
                {
                  "schemaVersion": "v1.1",
                  "lessonObjective": "string",
                  "styleConsistency": "string",
                  "frames": [
                    {
                      "index": 0,
                      "role": "word1_only|word2_only|overlap|non_interchangeable",
                      "targetWord": "word1|word2|both|contrast",
                      "title": "string",
                      "caption": "string",
                      "narrationText": "spoken English narration, 2-4 short sentences",
                      "imagePrompt": "cinematic visual prompt for one frame, landscape 16:9, no text",
                      "checkPrompt": "string or null",
                      "expectedAnswer": "string or null"
                    }
                  ]
                }
                """

                var response = ""
                for try await chunk in aiService.streamResponse(prompt) {
                    response += chunk
                }

                let cleaned = response
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let data = Data(cleaned.utf8)
                let plan = try JSONDecoder().decode(StoryboardPlan.self, from: data)
                try validate(plan)
                return plan
            }
        )
    }

    static var previewValue: Self {
        Self(
            plan: { word1, word2, _ in
                StoryboardPlan(
                    schemaVersion: "v1.1",
                    lessonObjective: "Build certainty about when to use each word in real communication.",
                    styleConsistency: "One vivid mini-story with recurring characters, cinematic educational storyboard style.",
                    frames: [
                        StoryboardFramePlan(
                            index: 0,
                            role: "word1_only",
                            targetWord: "word1",
                            title: "\(word1) fits naturally",
                            caption: "The situation clearly requires \(word1).",
                            narrationText: "At first, the learner is unsure. In this scene, everyone naturally uses \(word1). The meaning clicks because the action is concrete and clear.",
                            imagePrompt: "Cinematic storyboard frame, landscape 16:9, vivid daily-life scene where only \(word1) makes sense, recurring characters, natural lighting, no text, no subtitles, no letters.",
                            checkPrompt: "Which word fits this scene?",
                            expectedAnswer: word1
                        ),
                        StoryboardFramePlan(
                            index: 1,
                            role: "word2_only",
                            targetWord: "word2",
                            title: "\(word2) fits naturally",
                            caption: "A second scene where only \(word2) works.",
                            narrationText: "Now the story shifts to a different context. This time, only \(word2) sounds right. The contrast becomes obvious without grammar explanations.",
                            imagePrompt: "Cinematic storyboard frame, landscape 16:9, vivid scene that contrasts frame 1 and clearly favors \(word2), same characters, no text, no subtitles, no letters.",
                            checkPrompt: "Which word fits this scene?",
                            expectedAnswer: word2
                        ),
                        StoryboardFramePlan(
                            index: 2,
                            role: "overlap",
                            targetWord: "both",
                            title: "Both can work, but nuance changes",
                            caption: "A shared context shows subtle difference in tone or focus.",
                            narrationText: "Here both words are possible. But the feeling changes depending on which word is chosen. This gives the learner flexible but confident control.",
                            imagePrompt: "Cinematic storyboard frame, landscape 16:9, one scene where both words are possible with different nuance, expressive character reactions, no text, no subtitles, no letters.",
                            checkPrompt: nil,
                            expectedAnswer: nil
                        ),
                        StoryboardFramePlan(
                            index: 3,
                            role: "non_interchangeable",
                            targetWord: "contrast",
                            title: "Wrong swap, then correction",
                            caption: "A mistaken substitution is fixed immediately for clarity.",
                            narrationText: "Someone uses the wrong word and causes confusion. Another character corrects it right away. The learner now feels certain about which word to use in real speech.",
                            imagePrompt: "Cinematic storyboard frame, landscape 16:9, clear misunderstanding then correction moment, emotional clarity, same characters, no text, no subtitles, no letters.",
                            checkPrompt: "Can we swap the two words here?",
                            expectedAnswer: "No"
                        ),
                    ]
                )
            }
        )
    }

    static var testValue: Self {
        previewValue
    }
}

private func validate(_ plan: StoryboardPlan) throws {
    guard plan.frames.count == 4 else {
        throw StoryboardValidationError.frameCount(plan.frames.count)
    }
    let roles = Set(plan.frames.map(\.role))
    let required: Set<String> = ["word1_only", "word2_only", "overlap", "non_interchangeable"]
    guard roles == required else {
        throw StoryboardValidationError.missingRoles
    }
}

extension DependencyValues {
    var multimodalStoryboardPlanner: MultimodalStoryboardPlannerClient {
        get { self[MultimodalStoryboardPlannerClient.self] }
        set { self[MultimodalStoryboardPlannerClient.self] = newValue }
    }
}
