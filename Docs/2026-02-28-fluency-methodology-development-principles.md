# Fluency Methodology Development Principles
Date: 2026-02-28
Source: *The Strangest Fluency Secret* (through Chapter 7)
Purpose: Turn the book's learning model into enforceable product principles for all future WordsLearner features.

## 1. Core Thesis
Fluency problems are usually not caused by effort, talent, or motivation. They are caused by unresolved uncertainty in language use, especially under real communication variability.

The app must therefore optimize for:
1. Building certainty before speaking pressure.
2. Preparing users for unpredictable real communication.
3. Converting language knowledge into situationally appropriate expression.

## 2. Non-Negotiable Principles
1. Certainty first, output second.
2. A learner should not be forced to "perform to discover."
3. Learning units must be anchored in real situations, not isolated definitions.
4. Naturally varied review is the primary learning engine.
5. Depth of usable understanding beats breadth of shallow vocabulary.
6. Speaking practice is for consolidation and refinement, not initial comprehension.
7. Progress is local and compositional: certainty on many small units accumulates into fluency.

## 3. Definitions We Must Use
`Uncertainty`: A specific doubt about meaning, use, pronunciation, tone, appropriateness, or response timing.

`Naturally Varied Review`: Multiple understandable examples of the same target across varied contexts, tones, speakers, speeds, and structures, designed to trigger "aha" certainty.

`Preparation Gap`: The mismatch between controlled learning inputs and unpredictable real communication demands.

`Readiness`: The learner can use a target with low hesitation across expected variation in context.

## 4. Product Design Rules
1. Every feature must explicitly target uncertainty removal, not information display.
2. Every lesson must begin from a concrete situation and communicative intent.
3. Every target item must include varied examples, not a single canonical sentence.
4. Every lesson must include appropriateness guidance: what fits, what sounds off, and why.
5. Every flow must support 80-90% comprehensible input around the target so users can infer patterns without overload.
6. Every feature should let users cycle the same target through new contexts quickly.
7. Every output should prioritize "usable now" over "comprehensive explanation."
8. Every speaking activity should happen after clarity is established.

## 5. Prompt Engineering Rules
1. Prompt for context-rich mini stories first, not dictionary style explanations first.
2. Demand literal and figurative coverage when applicable.
3. Require multiple situational variants for the same target expression.
4. Require contrastive pairs for commonly confused forms.
5. Require appropriateness commentary: natural, awkward, too formal, too blunt, tone shift.
6. Require short, simple language that preserves clarity for learners.
7. Avoid large decontextualized rule dumps unless requested as secondary support.

## 6. Multimodal-Specific Rules
1. Multimodal lessons should represent a sequence of real situations, not only one abstract contrast template.
2. Each situation should reveal one uncertainty and resolve it through frame-level context.
3. Narration should guide inference from situation to language choice.
4. Visuals should show communicative context clearly enough that wording choice feels motivated.
5. Lessons must end with a context-specific conclusion about interchangeability for the user's sentence.
6. Final conclusion must be spoken audio and must reference evidence from prior situations.
7. "Can/cannot interchange" decisions must include rationale and counterexample when needed.

## 7. Lesson Construction Standard
Use this sequence for all new lesson generators:
1. Identify target uncertainty.
2. Select one concrete user-relevant situation.
3. Add naturally varied sister situations that preserve the target but change context.
4. Insert one overlap case where both forms may work but nuance differs.
5. Insert one non-interchangeable case with correction.
6. Produce a final user-sentence verdict with spoken summary.

## 8. QA Rubric (Ship Gate)
Ship only if all checks pass:
1. Clarity: Can learner explain why each word fits each situation?
2. Transfer: Can learner apply the choice to a novel but related situation?
3. Appropriateness: Does output distinguish natural vs merely grammatical?
4. Variation: Are there enough context shifts to avoid one-example memorization?
5. Conclusion integrity: Is final interchangeability verdict consistent with prior evidence?
6. Cognitive load: Is input mostly understandable while still informative?

## 9. Anti-Patterns (Must Avoid)
1. Definition-first flows with weak or absent contextual grounding.
2. One-example lessons that pretend to generalize broadly.
3. Grammar-table-heavy outputs as primary teaching mode.
4. "Just speak more" mechanics without readiness support.
5. Rigid scripts that ignore real-world phrasing variation.
6. Final verdicts not justified by lesson evidence.

## 10. PR Checklist for New Learning Features
1. What specific uncertainty does this feature remove?
2. Where is the naturally varied review mechanism?
3. How does this reduce the preparation gap for real conversations?
4. Where is situational appropriateness taught?
5. How does this feature support confidence before performance?
6. What measurable readiness signal proves success?

## 11. What This Means for Roadmap Decisions
Prioritize work that:
1. Increases certainty density per minute.
2. Improves variation quality across realistic situations.
3. Produces stronger final readiness in real communication contexts.

Deprioritize work that:
1. Adds content volume without uncertainty resolution.
2. Optimizes testing correctness without communicative readiness.
3. Increases complexity while reducing comprehensibility.
