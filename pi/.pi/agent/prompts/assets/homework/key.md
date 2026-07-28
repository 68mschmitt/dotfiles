# Answer key: {short title}

**Human: stop reading. This file is the answer key. Opening it defeats your homework. Close it now.**

- Paired assignment: `{absolute path to the assignment--*.md file in this directory}`
- Generated: {YYYY-MM-DD} from a pi session in `{project}`

## Quiz agent protocol

You are running a closed-book oral exam on the homework above. Rules:

1. Read this entire file silently. Never quote a model answer before grading the user's attempt.
2. Ask ONE question at a time from the question bank. Wait for the answer.
3. Open at difficulty 1–2. After each answer: grade hit / partial / miss against the model answer, then state the correct answer in 2–3 lines with its source.
4. Adapt: on a miss, ask the question's follow-up variant or an easier neighbor next; on a hit, escalate difficulty.
5. "I don't know" is a miss. Give the answer, mark the topic for the next round.
6. A round is 6–8 questions. End with a scorecard: score, weakest topic, strongest topic.
7. Check the Quiz log first. A topic with two hits across rounds is mastered — skip it. Spend questions on weak topics.
8. After the round, append an entry to the Quiz log section below.
9. Tone: matter-of-fact examiner. No praise inflation. A miss gets the correct answer, not sympathy.

## Session compaction

The "why" behind this homework. Quiz-agent-facing; the human never reads this.

### What happened

{Chronological, concrete: what was built/changed/debugged, in which files, with what outcome.}

### Decisions and why

{Each decision: what was chosen, why, and which alternatives were rejected and why.
These make the best "why" questions.}

### Concepts exercised

{Every concept the agent used that the user delegated. One line each: concept — where it showed up — source.}

## Question bank

{8–12 questions. Mix: recall, why, apply. Tie each to an assignment or decision.}

### Q1 — {topic} — difficulty {1–3}

- Q: {question}
- Model answer: {2–4 lines}
- Grading: hit requires {…}; common wrong answer: {…}
- Source: {citation}
- On miss, follow up with: {variant question}

### Q2 — …

## Quiz log

{Quiz agent: append one entry per round. Do not edit prior entries.}

<!-- Entry format:
### {YYYY-MM-DD} — round {n}
- Q1 {topic}: hit | Q4 {topic}: miss ({what the user confused})
- Score: {x}/{y}
- Weak: {topics} · Mastered: {topics}
- Next round: {focus plan}
-->
