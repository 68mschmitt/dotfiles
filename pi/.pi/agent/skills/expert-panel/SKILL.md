---
name: expert-panel
description: Convene a panel of isolated expert personas — legendary engineers, scientists, and designers — for independent, opinionated critique of a design, decision, or artifact. Load when the user asks for an expert panel, a review by famous experts, or multiple clashing perspectives on a decision with real trade-offs.
---

# Expert Panel

The `consult_panel` tool convenes a panel of expert personas. Each consultant runs as a **fully isolated** process: it sees only its persona plus the `question`, `context`, and `decision_criteria` you pass. It has **no tools, no files, no skills, and no access to this conversation** — so whatever you don't write down does not exist for it. Thin context produces generic "it depends" answers; a self-contained brief with an explicit decision criterion produces sharp, high-value ones. It answers once and stops.

Do **not** read the persona files; this roster is all the selection context you need (full persona prompts are injected into consultants automatically). Do **not** role-play the personas yourself — always use the tool so opinions are formed independently.

## Roster

### Engineering & science

| Persona | Domain | Consult when | Bias |
|---|---|---|---|
| `linus-torvalds` | Systems architecture, code quality, kernel-level design, rejecting unnecessary abstraction | Kernel-level design, data-structure choices, "is this overengineered?", code-taste calls | Pragmatism over theory; brutal about needless complexity |
| `ken-thompson` | Radical minimalism, composable tools, API surface reduction, deleting code | "Can this be smaller?", API surface trimming, deciding what to delete | When in doubt, leave it out; distrusts features |
| `john-carmack` | Performance engineering, optimization, latency, profiling-driven development | Hot paths, latency budgets, optimization strategy, profiling plans | Measure first; respects the hardware; suspicious of indirection |
| `donald-knuth` | Algorithm analysis, mathematical rigor, literate programming, correctness | Algorithm selection, complexity analysis, correctness of tricky code | Rigor and proof over intuition; warns against premature optimization |
| `edsger-dijkstra` | Formal reasoning, structured programming, correctness proofs, mathematical discipline | Correctness arguments, invariants, structured control flow, "can we prove it?" | Elegance is not optional; contemptuous of testing as proof |
| `leslie-lamport` | Distributed systems, consensus, formal specification, TLA+, concurrency | Distributed systems, concurrency, consensus, specification before code | If you didn't specify it, you don't understand it |
| `rich-hickey` | Simplicity vs. complexity, immutability, state management, data-oriented design | State management, data modeling, simple-vs-easy calls, decomplecting a design | Immutability and data over objects; hostile to incidental complexity |
| `kent-beck` | TDD, refactoring, incremental design, making change safe, XP practices | Test strategy, refactoring plans, incremental delivery, design feedback loops | Small safe steps; make it work, then make it right |
| `martin-fowler` | Refactoring strategy, enterprise patterns, evolutionary architecture, continuous delivery | Refactoring large codebases, enterprise architecture, evolutionary design | Patterns and process; tolerant of pragmatic compromise |
| `joshua-bloch` | API design, library design, Java best practices, interface contracts | Public API shape, library contracts, naming, versioning | APIs are forever; design for the caller, minimize surprise |
| `brian-kernighan` | Code clarity, technical writing, Unix philosophy, readability | Readability review, documentation, tool design, Unix-style solutions | Clarity beats cleverness every time |
| `bjarne-stroustrup` | Language design trade-offs, type systems, zero-overhead abstraction, C++ | Type-system design, zero-overhead abstraction, language feature trade-offs | Abstraction should cost nothing; defends necessary complexity |
| `richard-gabriel` | Software philosophy, "worse is better", aesthetics of design, patterns | Worse-is-better calls, shipping vs. polish, design philosophy disputes | Evolution beats perfection; suspicious of grand designs |
| `claude-shannon` | Information theory, entropy, coding theory, channel capacity, mathematical modeling | Information flow, encoding, compression, channel-and-noise framing of a problem | Quantify uncertainty; strip a problem to its mathematical core |
| `alan-turing` | Computability theory, decidability, formal models of computation, AI philosophy | Computability limits, formal models, what machines can and cannot decide | Formalism first; unmoved by practical inconvenience |
| `john-von-neumann` | Computer architecture, mathematical modeling, game theory, numerical methods | Architecture trade-offs, numerical methods, game-theoretic framing | Raw analytical power; assumes the math settles it |
| `john-mccarthy` | AI foundations, Lisp, symbolic computation, garbage collection, formal reasoning | Symbolic computation, language expressiveness, AI-flavored designs | Programs as formal objects; Lisp is the answer more often than not |
| `dennis-ritchie` | C language design, systems programming, OS/language co-design, abstraction | Systems-language design, OS interfaces, minimal sufficient abstraction | Quiet minimalism; the tool should disappear |
| `doug-mcilroy` | Unix pipes, software composability, component architecture, interface minimalism | Composability, pipelines, component boundaries, small-tools design | Write programs that do one thing well and compose |
| `richard-hamming` | Error-correcting codes, numerical methods, research methodology, doing important work | Research direction, "are we working on the important problem?", methodology | Attack important problems; luck favors the prepared mind |
| `richard-feynman` | First-principles reasoning, explanation quality, debugging by simplification, cargo-cult critique | First-principles sanity checks, debugging by simplification, cargo-cult smells | If you can't explain it simply, you don't understand it |
| `carl-sagan` | Scientific skepticism, big-picture systems thinking, evidence-based explanation, perspective | Evidence quality, extraordinary claims, big-picture framing for lay audiences | Skepticism plus wonder; demands evidence proportional to claims |
| `salman-khan` | Pedagogy, scaffolded explanation, mastery learning, learner-centered clarity | Explaining to learners, onboarding, documentation pedagogy, mastery sequencing | Meet the learner where they are; no gaps allowed |
| `grant-sanderson` | Visual intuition, mathematical explanation, conceptual animation, structure-first teaching | Building intuition, visual explanation, structuring a hard concept | Intuition before formalism; find the picture |
| `john-tukey` | Exploratory data analysis, FFT, statistical methodology, data visualization | Data exploration, statistics, visualization choices, what the data actually says | Look at the data first; approximate answers to the right questions |
| `john-backus` | Fortran, BNF, functional programming advocacy, language implementation | Language implementation, functional style, escaping the von Neumann bottleneck | Repented of imperative state; champions function-level programming |
| `niklaus-wirth` | Language design simplicity, compiler construction, software bloat critique, Oberon | Bloat critique, language and compiler simplicity, "what would this look like lean?" | Software grows fatter faster than hardware grows faster |
| `barbara-liskov` | Abstract data types, substitution principles, type hierarchy design, program methodology | Type hierarchies, substitutability, abstraction boundaries, module contracts | Abstractions must honor their contracts, no exceptions |
| `alan-kay` | Object-oriented design (messaging), personal computing vision, paradigm shifts, Smalltalk | Paradigm-level critique, messaging vs. objects, long-view computing vision | The computer revolution hasn't happened yet; despises pop OO |
| `tim-berners-lee` | Web architecture, protocol design, open standards, linked data, decentralization | Protocol and web architecture, open standards, decentralization, linked data | Universality and openness over vendor convenience |
| `douglas-engelbart` | Human-computer interaction, augmented intelligence, collaborative tools, tool philosophy | Tools for thought, collaboration systems, augmenting humans vs. automating them | Augment human intellect; co-evolve tools and practices |
| `mark-zuckerberg` | Product strategy, platform thinking, shipping speed, scaling decisions | Ship-vs-polish, platform strategy, growth and scaling calls | Move fast; code wins arguments; done is better than perfect |

### Design & communication

| Persona | Domain | Consult when | Bias |
|---|---|---|---|
| `paul-rand` | Creative direction, brand identity systems, logo critique, visual restraint | Logo and identity critique, brand systems, visual restraint decisions | Simplicity and wit; the designer decides, the client approves |
| `jony-ive` | Product form, material honesty, restraint, craft, hardware-software coherence | Product form, materials, craft, coherence of hardware and software feel | Obsessive reduction; care is felt even when unseen |
| `don-norman` | Human-centered design, usability, affordances, signifiers, feedback, mental models | Usability review, affordances, error states, mental-model mismatches | Blame the design, never the user |
| `david-ogilvy` | Advertising, positioning, copy, persuasion, research, campaign strategy | Positioning, copy, campaign strategy, "does this actually sell?" | Research-driven persuasion; if it doesn't sell, it isn't creative |
| `paula-scher` | Typography, expressive identity systems, cultural branding, environmental graphics | Typography, expressive identity, cultural voice, environmental graphics | Bold public expression over tasteful neutrality |
| `susan-kare` | Icon design, interface metaphors, pixel craft, visual warmth, small-scale clarity | Icons, interface metaphors, small-scale clarity, visual warmth | Friendly and legible at 16 pixels, or it fails |
| `edward-tufte` | Data visualization, evidence presentation, chartjunk removal, analytical clarity | Charts, dashboards, evidence display, chartjunk removal | Maximize data-ink; decoration is a moral failing |

## Protocol

### When to convene a panel

- Architecture or engineering decisions with meaningful trade-offs
- Reviews where perspective on style, correctness, or philosophy matters
- Technology, paradigm, or API/interface selection
- Brand, product, UX, typography, iconography, or data-visualization critique
- Performance vs. clarity vs. safety tensions; ship-now vs. design-more calls

### When NOT to convene

- Mechanical implementation with no design ambiguity
- Typo fixes, formatting, simple edits, or information gathering
- Tasks with one obvious correct answer, or where a project rule already decides

### How

1. **Pick 2–4 personas** whose domains fit and who are likely to **disagree** — the value is in the tension.
2. **Write one sharp question** every expert answers. Prefer a concrete decision ("X or Y, given …?") over "any thoughts?".
3. **Brief the experts — this is where the value is won or lost.** The `context` string is their entire world; they cannot fetch anything. Assemble a self-contained brief using the checklist below, and paste any code/design/spec **verbatim** rather than summarizing it. Keep it tight, but include whatever an expert would otherwise have to ask for.
4. **State the `decision_criteria`.** Name the real trade-off(s) in tension and how you'll judge them (e.g. "correctness under contention over write latency"). This is what turns a generic "it depends" into a decisive opinion — required even for quick consults.
5. **Call the tool:** `consult_panel({ question, context, decision_criteria, personas: ["id", ...] })` (max 4 per call).
6. **Synthesize** for the user: agreements (high confidence), genuine disagreements as attributed trade-offs, then your own concrete recommendation.

### Context checklist

The experts otherwise have to *guess* at these. Before calling, make sure your `context` + `decision_criteria` cover the ones that apply (not all apply every time):

- **Artifact** — the actual code, design, schema, or decision, pasted **verbatim** (not paraphrased).
- **Goal** — what you're trying to achieve and why; what "done" looks like.
- **Constraints** — the hard limits: scale, latency/throughput budgets, team size, deadline, budget, compatibility, platform.
- **Alternatives** — the options you're choosing between, plus anything already tried and rejected (and why).
- **Criteria** — what a good answer must optimize for; the trade-off you actually care about (this is the `decision_criteria` field).

**Self-test:** if you can imagine any expert answering "it depends…", the brief is missing the deciding detail — add it before you call.

### Good panel compositions

- API design: `joshua-bloch` + `ken-thompson` (thoroughness vs. minimalism)
- Performance vs. readability: `john-carmack` + `brian-kernighan` (speed vs. clarity)
- Testing strategy: `kent-beck` + `edsger-dijkstra` (TDD vs. formal correctness)
- State management: `rich-hickey` + `linus-torvalds` (immutability vs. pragmatism)
- Ship now vs. design more: `mark-zuckerberg` + `donald-knuth` (speed vs. rigor)
- Brand identity system: `paul-rand` + `paula-scher` (restraint vs. expressive public voice)
- Product experience: `jony-ive` + `don-norman` (refined coherence vs. observable usability)
- Campaign direction: `david-ogilvy` + `paul-rand` (selling proposition vs. durable identity)
- Icon and interface metaphor: `susan-kare` + `don-norman` (small-scale clarity vs. cognitive model)
- Data-heavy product: `edward-tufte` + `don-norman` (evidence integrity vs. human task flow)
- Explaining something hard: `grant-sanderson` + `salman-khan` (intuition vs. scaffolding)
