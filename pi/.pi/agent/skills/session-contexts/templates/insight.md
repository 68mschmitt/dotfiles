---
project: {project}
theme: {lesson-theme}
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
tags: [session-context, insight]
---

# {Title stating the claim, e.g. "Retry storms came from the client timeout being shorter than the server's p99"}

**In one line:** {the insight compressed to its sharpest form.}

## The insight

{The cohesive write-up. Self-contained prose that makes its case: what is true,
how it was discovered, why it defied the obvious expectation. A reader with no
session context must be able to follow it end to end. Typically 2–5 paragraphs.}

## Evidence

{The verbatim artifacts that ground the claim: commands run and their output,
error messages, file paths with line references, code snippets. Enough for a
skeptical future reader to re-verify. Redact secrets as {REDACTED}.}

## How to apply it

{When would a future session need this doc, and what should it do differently
because of it? Concrete: the command to run, the file to check, the trap to avoid.}

## Limits and unknowns

{Where the insight stops: what it does not cover, what was not verified, and any
version or environment specifics it may depend on.}
