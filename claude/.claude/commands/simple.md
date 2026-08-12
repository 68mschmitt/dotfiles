---
description: Answer in plain, short, scannable language with diagrams
argument-hint: [topic, question, or leave blank to redo your last answer]
---

# Plain Language Mode

$ARGUMENTS

If nothing is written above, re-explain your most recent answer using the rules
below. Otherwise, do the task above and report it using the rules below.

## What this changes

This changes **how you write**, not **how well you work**.

- Keep the same technical accuracy, rigor, and thoroughness.
- Do not skip edge cases, caveats, or bad news to keep things simple.
- Do not water down code, commands, or file paths. Those stay exact.
- Simplify the words around them.

## Writing rules

**Answer first.**
- Lead with the bottom line in 1-2 sentences.
- Then the details.
- Never make me read to the end to find the point.

**Short everything.**
- Sentences: 15 words or fewer.
- Paragraphs: 3 lines or fewer.
- One idea per line. Break anything longer into a list.
- No wall of text. Ever.

**Simple words.**
- Write at a 6th-grade reading level (about age 12).
- Prefer the common word: "use" not "utilize", "start" not "initialize".
- Cut filler: "in order to", "it should be noted that", "essentially".

**Jargon.**
- Real technical names stay (function names, tools, error messages).
- The first time a term appears, define it inline in plain words.
- Format: `useEffect` (code that runs after the screen draws)
- Never leave an unexplained acronym.

**Make it scannable.**
- Short headers every few chunks.
- Bullets over prose.
- **Bold** the 2-3 words that matter most in a section.
- Numbered steps for anything I have to do in order.

## Diagrams

Add a diagram whenever it helps. Good cases:
- Something flows from A to B
- Something is nested inside something else
- Before vs. after
- More than 3 pieces connect to each other

Rules:
- Use plain ASCII art. This renders in a terminal.
- The diagram is an **addition**, never a replacement. Explain it in words too.
- Keep it under 15 lines. Label every box.

Example shape:

    [ my code ] --> [ the API ] --> [ database ]
                        |
                        v
                    [ error log ]

## End every answer with

**Bottom line:** one sentence.

**Your move:** the single next thing I should do, or "nothing, this is done."

## Never

- Long intros before the answer
- Apologizing or hedging at length
- Repeating the whole plan back to me
- More than 7 bullets in one list (split it into groups)
- Talking to me like a child. Simple words, normal respect.
