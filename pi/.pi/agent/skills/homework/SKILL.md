---
name: homework
description: Turn a pi session into homework the user completes away from AI, then run closed-book oral quizzes on it in a later session. Two modes. Generate — use when the user says "give me homework", "homework time", or wants to walk away with learning instead of just delegating. Quiz — use when the user says "quiz me", "quiz me on <file>", or points at a file under ~/projects/second-brain/homework/.
---

# homework

The user delegates work to pi, then learns nothing. This skill fixes that: at session end it produces a homework assignment (human-facing) plus an answer key (agent-facing, never read by the human). Later, a fresh pi session uses the key to run a closed-book oral exam.

Two modes. Detect which one applies and follow only that section.

- **Generate mode**: the current session did real work and the user wants homework from it.
- **Quiz mode**: the user wants to be examined on previously generated homework.

## File layout

All artifacts live under `~/projects/second-brain/homework/`:

```
~/projects/second-brain/homework/
  {project}/                        # basename of git root, else basename of cwd
    {lesson-theme}/                 # slug of the lesson theme, e.g. jwt-refresh-rotation
      assignment--{YYYY-MM-DD}.md   # homework: the user READS and DOES this
      key--{YYYY-MM-DD}.md          # answer key + quiz log: the user NEVER reads this
```

Filenames must start with `assignment` and `key`; the suffix after `--` is context (default: generation date). The assignment file must be fully self-sufficient for doing the homework. The key file holds session context ("why"), the question bank, model answers, and the quiz log. Splitting them is the point: answers never sit in a file the human opens.

## Generate mode

### When

Trigger phrases: "give me homework", "homework time", "make homework from this session", or the user asks to wrap up with something to learn from. If the session has no substantial work yet (nothing built, decided, or debugged), say so in one line and stop.

### Steps

1. Pick a lesson-theme slug from the session's dominant subject (e.g. `jwt-refresh-rotation`, not `misc-fixes`).
2. Resolve the target directory; if the theme directory already contains an assignment, use `{theme}-2`:
   ```bash
   project=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
   mkdir -p ~/projects/second-brain/homework/"$project"/"$theme"
   ```
   Files go in that directory as `assignment--{YYYY-MM-DD}.md` and `key--{YYYY-MM-DD}.md`.
3. Mine the session for the **delegation gap**: things the agent did, decided, or knew that the user did not do themselves. Those are the teachable items. Ignore things the user did or clearly already knows.
4. Verify sources. Every concept taught must cite a primary source (official docs, RFC, man page, spec). Use `web_search` to confirm any URL or claim you are not certain of. A source you could not verify gets marked `(unverified)`. Never invent citations — this artifact exists partly to prove the material was not hallucinated.
5. Write the assignment file from [templates/assignment.md](templates/assignment.md). Rules:
   - 3–5 assignments, each 10–45 min with a concrete time estimate.
   - Each assignment starts with a verb and is doable away from this session (fresh scratch dir, reading, or a bounded exercise in the repo).
   - Include at least one **rebuild-from-scratch** item (redo a thing the agent did, without looking at the agent's version) and at least one **explain-why** item (write or say the reasoning behind a session decision).
   - The Context section is 2–4 sentences and contains no quiz answers.
6. Write the key file from [templates/key.md](templates/key.md). Rules:
   - Session compaction is thorough — it is the quiz agent's ONLY context. Record what happened, each decision with its why, rejected alternatives, and every concept exercised.
   - Question bank: 8–12 questions, each tied to an assignment or decision. Mix recall ("what is X"), why ("why X over Y"), and apply ("given Z, what breaks"). Each question carries a model answer, grading notes (what a hit must contain, the common wrong answer), difficulty 1–3, a source, and a follow-up variant for misses.
   - Leave the Quiz log section empty.
7. Report to the user: the two file paths, the assignment list with time estimates and total time, and the exact quiz command:
   ```
   quiz me on ~/projects/second-brain/homework/{project}/{theme}/assignment--{YYYY-MM-DD}.md
   ```
   Tell them not to open the `key--*.md` file — it is the answer key.

## Quiz mode

### When

Trigger phrases: "quiz me", "quiz me on <path>", "test me on my homework", or any request referencing a file under `~/projects/second-brain/homework/`. If no path was given, list the lesson themes (`ls -dt ~/projects/second-brain/homework/*/*/`), show the most recent 5, and ask which one.

### Steps

1. Resolve files. Given the assignment file or the theme directory, the key is the `key--*.md` in that same directory (also named in the assignment header). Given the key file directly, use it. If the key file is missing, say so and offer a degraded quiz from the assignment file alone.
2. Read the key file silently. Do not quote, summarize, or display its contents. Remind the user once: closed book, no peeking at notes or the read output.
3. Run the exam by the **Quiz agent protocol** embedded in the key file. Summary of that protocol (the file's version wins if they differ):
   - One question at a time. Wait for the answer.
   - Grade each answer hit / partial / miss against the model answer, then give the correct answer in 2–3 lines with its source.
   - "I don't know" is a miss: give the answer, mark the topic.
   - Adapt: miss → follow-up variant or easier neighbor; hit → harder.
   - A round is 6–8 questions, then a scorecard: score, weakest topic, strongest topic.
   - If the Quiz log shows a topic hit twice across rounds, skip it; spend the budget on weak topics.
4. Append a round entry to the Quiz log section of the key file (date, per-question results, score, weak topics, plan for next round).
5. Close with one line: the score and the single topic to review before the next round.

Tone throughout: matter-of-fact examiner. No praise inflation, no sympathy for misses — state what was wrong and what the right answer is.
