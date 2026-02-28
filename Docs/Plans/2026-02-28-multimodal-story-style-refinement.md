# Multimodal Story-Style Refinement (V2)
Date: 2026-02-28
Scope: Refine multimodal lesson generation to follow the existing comparison story style.

## 1. Style Target (What to Preserve)
From the text comparison style (example: `victimise` vs `disadvantage`), we must preserve:
1. Concrete, visual mini-stories with named characters.
2. Elementary-level language (short, simple, spoken sentences).
3. Explicit story-to-word link:
   `In this story, X [target-word] Y.`
4. Clear meaning explanation after each story.
5. Contrastive explanation:
   intent, result, and when words are/are not interchangeable.
6. Final sentence-specific verdict with practical tone guidance.

## 2. Lesson Structure (New Multimodal Goal)
Current problem: one 4-frame lesson is too compressed.

Refined structure:
1. Story A block (4 frames): word1-focused situation.
2. Story B block (4 frames): word2-focused situation.
3. Optional Story C block (4 frames): overlap/nuance case (only when useful).
4. Final conclusion block (1-2 frames): interchangeability verdict for the user's sentence.

Each frame has:
1. Image prompt.
2. Narration text.
3. Caption (supporting text).

The final conclusion must always include audio narration.

## 3. 4-Frame Pattern Per Story
For each story block, use this fixed progression:
1. Setup: who, where, and context.
2. Conflict/Action: key event showing the target usage pressure.
3. Outcome: consequence and emotional/functional result.
4. Language lock-in: explicit sentence linking story to word meaning (and brief usage check).

This keeps cinematic flow while preserving the existing pedagogical style.

## 4. Prompt Refinement Requirements
Planner prompt must instruct the model to:
1. First think like the text-comparison feature (story-first clarity).
2. Generate two distinct mini-stories that clearly separate word meanings.
3. Use elementary spoken English (no jargon, no dense grammar labels).
4. Make at least one story clearly tied to the user sentence context.
5. Produce a direct final verdict:
   `Can these words be interchanged in the user's sentence? yes/no/depends + reason`.
6. Provide tone note:
   neutral vs emotional/accusatory usage difference when applicable.
7. Output structured JSON only (for deterministic rendering).

## 5. Planner JSON Shape (V2)
Use this schema direction:

```json
{
  "schemaVersion": "v2.0",
  "lessonObjective": "string",
  "stories": [
    {
      "storyID": "story_a",
      "focusWord": "word1|word2|both",
      "title": "string",
      "meaningSummary": "string",
      "frames": [
        {
          "indexInStory": 0,
          "globalIndex": 0,
          "role": "setup|conflict|outcome|language_lock_in",
          "title": "string",
          "caption": "string",
          "narrationText": "string",
          "imagePrompt": "string",
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
    "imagePrompt": "string"
  }
}
```

## 6. Generation Rules
1. Never collapse both words into one vague story.
2. Each story must prove one usage boundary.
3. Story B must not paraphrase Story A with swapped nouns.
4. Language-lock-in frame must include explicit phrase:
   `In this story, ...`
5. Final conclusion narration must reference evidence from Story A/B.
6. If verdict is `depends`, provide one condition for each word.

## 7. UX/Playback Rules
1. Play order: Story A -> Story B -> optional Story C -> Final Conclusion.
2. Show story separators and frame progress within each story.
3. "Play All" must continue across story boundaries.
4. Conclusion frame should have a distinct visual badge (`Final Verdict`).

## 8. Quality Gates (Before Persisting Lesson)
Reject/regenerate if:
1. Any story block is not exactly 4 frames.
2. Stories are semantically duplicate.
3. User sentence is ignored in final verdict.
4. Conclusion narration is missing or vague.
5. Word contrast remains unclear after frame 4 of Story A/B.

## 9. Implementation Targets
Primary files to update when implementing:
1. `WordsLearner/Services/MultimodalStoryboardPlannerClient.swift`
2. `WordsLearner/Services/MultimodalLessonGeneratorClient.swift`
3. `WordsLearner/Database/MultimodalLessonFrame.swift` (optional extra metadata)
4. `WordsLearner/Features/MultimodalLessonDetailView.swift`
5. `WordsLearner/Features/MultimodalLessonsView.swift` (story/frame progress labeling)

