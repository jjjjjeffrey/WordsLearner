//
//  MultimodalStoryboardPlannerClientTests.swift
//  WordsLearnerTests
//

import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import WordsLearner

@MainActor
struct MultimodalStoryboardPlannerClientTests {
    private final class LockedBox<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Value

        init(_ value: Value) {
            self.value = value
        }

        func withValue<R>(_ body: (inout Value) -> R) -> R {
            lock.lock()
            defer { lock.unlock() }
            return body(&value)
        }

        func snapshot() -> Value where Value: Sendable {
            withValue { $0 }
        }
    }

    @Test
    func plannerRetriesAfterValidationFailure_andReturnsValidPlan() async throws {
        let prompts = LockedBox<[String]>([])
        let responses = LockedBox([
            oneStoryInvalidPlanJSON(),
            validPlanJSON(sentence: "The policy affects the effect.")
        ])

        let plan = try await withDependencies {
            $0.aiService = AIServiceClient(
                streamResponse: { prompt in
                    prompts.withValue { $0.append(prompt) }
                    let payload = responses.withValue { queue in
                        queue.removeFirst()
                    }
                    return AsyncThrowingStream { continuation in
                        continuation.yield(payload)
                        continuation.finish()
                    }
                }
            )
        } operation: {
            try await MultimodalStoryboardPlannerClient.liveValue.plan(
                "affect",
                "effect",
                "The policy affects the effect."
            )
        }

        #expect(plan.stories.count == 2)
        let capturedPrompts = prompts.snapshot()
        #expect(capturedPrompts.count == 2)
        #expect(capturedPrompts[1].contains("Retry note:"))
    }

    @Test
    func plannerFailsAfterThreeInvalidAttempts() async throws {
        let attempts = LockedBox(0)
        do {
            _ = try await withDependencies {
                $0.aiService = AIServiceClient(
                    streamResponse: { _ in
                        attempts.withValue { $0 += 1 }
                        return AsyncThrowingStream { continuation in
                            continuation.yield("{\"not\":\"valid json for this schema\"}")
                            continuation.finish()
                        }
                    }
                )
            } operation: {
                try await MultimodalStoryboardPlannerClient.liveValue.plan(
                    "affect",
                    "effect",
                    "The policy affects the effect."
                )
            }
            Issue.record("Expected planner to fail after 3 invalid attempts.")
        } catch {}

        #expect(attempts.snapshot() == 3)
    }
}

private func oneStoryInvalidPlanJSON() -> String {
    """
    {
      "schemaVersion": "v2.0",
      "lessonObjective": "Build certainty",
      "styleConsistency": "Story-first",
      "stories": [
        {
          "storyID": "story_a",
          "focusWord": "affect",
          "title": "Story A",
          "meaningSummary": "Meaning",
          "frames": [
            {
              "indexInStory": 0,
              "globalIndex": 0,
              "role": "setup",
              "targetWord": "affect",
              "title": "Setup",
              "caption": "Setup",
              "narrationText": "A setup scene.",
              "imagePrompt": "16:9 setup",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 1,
              "globalIndex": 1,
              "role": "conflict",
              "targetWord": "affect",
              "title": "Conflict",
              "caption": "Conflict",
              "narrationText": "A conflict scene.",
              "imagePrompt": "16:9 conflict",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 2,
              "globalIndex": 2,
              "role": "outcome",
              "targetWord": "affect",
              "title": "Outcome",
              "caption": "Outcome",
              "narrationText": "An outcome scene.",
              "imagePrompt": "16:9 outcome",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 3,
              "globalIndex": 3,
              "role": "language_lock_in",
              "targetWord": "affect",
              "title": "Lock",
              "caption": "Lock",
              "narrationText": "In this story, affect is right.",
              "imagePrompt": "16:9 lock",
              "checkPrompt": null,
              "expectedAnswer": null
            }
          ]
        }
      ],
      "finalConclusion": {
        "verdict": "depends",
        "verdictReason": "Context.",
        "sentenceFromUser": "The policy affects the effect.",
        "recommendedUsage": "Use intent.",
        "toneDifferenceNote": "Tone varies.",
        "narrationText": "Depends on context.",
        "imagePrompt": "16:9 final"
      }
    }
    """
}

private func validPlanJSON(sentence: String) -> String {
    """
    {
      "schemaVersion": "v2.0",
      "lessonObjective": "Build certainty",
      "styleConsistency": "Story-first",
      "stories": [
        {
          "storyID": "story_a",
          "focusWord": "affect",
          "title": "Story A",
          "meaningSummary": "Meaning A",
          "frames": [
            {
              "indexInStory": 0,
              "globalIndex": 0,
              "role": "setup",
              "targetWord": "affect",
              "title": "Setup",
              "caption": "Setup",
              "narrationText": "A setup scene.",
              "imagePrompt": "16:9 setup",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 1,
              "globalIndex": 1,
              "role": "conflict",
              "targetWord": "affect",
              "title": "Conflict",
              "caption": "Conflict",
              "narrationText": "A conflict scene.",
              "imagePrompt": "16:9 conflict",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 2,
              "globalIndex": 2,
              "role": "outcome",
              "targetWord": "affect",
              "title": "Outcome",
              "caption": "Outcome",
              "narrationText": "An outcome scene.",
              "imagePrompt": "16:9 outcome",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 3,
              "globalIndex": 3,
              "role": "language_lock_in",
              "targetWord": "affect",
              "title": "Lock",
              "caption": "Lock",
              "narrationText": "In this story, affect is right.",
              "imagePrompt": "16:9 lock",
              "checkPrompt": "Which fits?",
              "expectedAnswer": "affect"
            }
          ]
        },
        {
          "storyID": "story_b",
          "focusWord": "effect",
          "title": "Story B",
          "meaningSummary": "Meaning B",
          "frames": [
            {
              "indexInStory": 0,
              "globalIndex": 4,
              "role": "setup",
              "targetWord": "effect",
              "title": "Setup",
              "caption": "Setup",
              "narrationText": "Another setup scene.",
              "imagePrompt": "16:9 setup",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 1,
              "globalIndex": 5,
              "role": "conflict",
              "targetWord": "effect",
              "title": "Conflict",
              "caption": "Conflict",
              "narrationText": "Another conflict scene.",
              "imagePrompt": "16:9 conflict",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 2,
              "globalIndex": 6,
              "role": "outcome",
              "targetWord": "effect",
              "title": "Outcome",
              "caption": "Outcome",
              "narrationText": "Another outcome scene.",
              "imagePrompt": "16:9 outcome",
              "checkPrompt": null,
              "expectedAnswer": null
            },
            {
              "indexInStory": 3,
              "globalIndex": 7,
              "role": "language_lock_in",
              "targetWord": "effect",
              "title": "Lock",
              "caption": "Lock",
              "narrationText": "In this story, effect is right.",
              "imagePrompt": "16:9 lock",
              "checkPrompt": "Which fits?",
              "expectedAnswer": "effect"
            }
          ]
        }
      ],
      "finalConclusion": {
        "verdict": "depends",
        "verdictReason": "Context.",
        "sentenceFromUser": "\(sentence)",
        "recommendedUsage": "Use intent.",
        "toneDifferenceNote": "Tone varies.",
        "narrationText": "Depends on context.",
        "imagePrompt": "16:9 final"
      }
    }
    """
}
