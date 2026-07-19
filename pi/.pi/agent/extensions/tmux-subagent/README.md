# tmux-subagent

Delegate tasks to specialized subagents. By default this install is configured to
run them **headless**; set `tmuxSubagent.defaultTransport` to `"auto"` or `"tmux"`
to run them live in a new, dedicated tmux window (a “tab”) so you can watch them
work while the result still flows back to the calling model. A lone visible
subagent gets its own window; visible parallel tasks share one window as panes —
the active pi pane is never split.

pi ships no built-in subagents on purpose — its docs point you at exactly this:
spawn `pi` instances via tmux, or build it with an extension. This is that extension,
adapted from pi's official `examples/extensions/subagent` with the children running in
observable tmux panes instead of a hidden pipe.

## How it works

For each subagent call, the tool:

0. Resolves the transport from the tool call's `transport` parameter, falling back
   to `tmuxSubagent.defaultTransport` in settings.json (`"auto"` by default):
   `"hidden"` runs headless; `"auto"`/`"tmux"` use tmux when available.
1. When using tmux, opens a new dedicated tmux window (`tmux new-window`) whose status-bar label is
   derived from the **calling session** — the session name if set, else the project
   directory basename — plus a short suffix: `<caller>/<agent>` for a single run
   (e.g. `dotfiles/scout`) or `<caller>/<N>x` for parallel (e.g. `dotfiles/3x`). The
   label is sanitized of status-bar-special characters and capped (~18 chars) so it
   fits the status bar. Parallel tasks split that same window into equal-width,
   side-by-side panes, each pane titled `subagent: <name>`.
2. Runs `pi --mode json --no-session [--model …] [--tools …] [--append-system-prompt …] "Task: …"`
   in that pane.
3. Pipes pi's JSON event stream through a tiny renderer (`stream-render.mjs`, embedded
   in `index.ts` and written per-run to a temp dir) that:
   - renders a **styled, navigable session** into the pane rather than a wall of white
     text: a header banner (agent + task), a dimmed italic **thinking** block with a
     `│` left gutter (clearly the model's scratch reasoning, not the answer), the
     bright **response** block, and compact `→ tool` lines with `✓`/`✗` result
     previews — all separated by blank lines and framed with horizontal rules, and
   - tees the raw JSONL to a temp file.
4. Tails that temp file to stream progress into the parent pi TUI and to capture the
   final assistant message for the calling model.
5. Detects completion via an `exit.code` sentinel written after the pipe (`set -o pipefail`
   + `${PIPESTATUS[0]}`), with `agent_end` / pane-death as fallbacks.

`remain-on-exit on` keeps the finished (dead) pane open so you can scroll it. Ctrl+C in
the parent aborts and kills the pane. With `"hidden"` transport, or when not inside
tmux, it uses a hidden headless run.

## Agents

Markdown files with frontmatter in `~/.pi/agent/agents/*.md` (user) or
`<project>/.pi/agents/*.md` (project). See the sibling `../../agents/` dir for samples:

| Agent | Purpose | Model | Tools |
|-------|---------|-------|-------|
| `scout` | Fast read-only recon | `claude-haiku-4-5` | read, grep, find, ls, bash |
| `planner` | Implementation plans | `claude-sonnet-4-6` | read, grep, find, ls |
| `reviewer` | Code / diff review | `claude-sonnet-4-6` | read, grep, find, ls, bash |
| `mission-control` | General implementation (flight-controller discipline) | (your default) | all default |

```markdown
---
name: my-agent
description: What this agent is for (the parent model reads this to choose it)
tools: read, grep, find, ls
model: claude-haiku-4-5
---
System prompt for the agent.
```

## Settings

Configure defaults in `~/.pi/agent/settings.json` (or a trusted project
`.pi/settings.json`):

```json
{
  "tmuxSubagent": {
    "defaultTransport": "hidden"
  }
}
```

`defaultTransport` values:
- `"hidden"` — never open a tmux tab/pane; run the child headless.
- `"auto"` — use tmux when `$TMUX` is present; otherwise headless.
- `"tmux"` — request tmux when available; falls back to headless outside tmux.

Optional defaults for existing tool parameters are also supported:
`layout`, `focus`, `keepPaneOpen`, and `timeoutSeconds`.

## Usage

Single:
```
Use the scout subagent to find where the read tool is defined.
```
Parallel (visible transport: one pane each, side-by-side equal width; max 4):
```
Run two scouts in parallel: one to map the providers, one to map the tools.
```

## Tool parameters

| Param | Default | Notes |
|-------|---------|-------|
| `agent` + `task` | — | single mode |
| `tasks: [{agent, task, cwd?}]` | — | parallel mode (max 4 panes) |
| `agentScope` | `user` | `user` \| `project` \| `both` |
| `confirmProjectAgents` | `true` | confirm before running repo-controlled agents |
| `layout` | settings or `h` | `h` = equal-width columns (even-horizontal); `v` = equal-height rows (even-vertical) |
| `transport` | settings or `auto` | `auto`/`tmux` use tmux when available; `hidden` never opens a tmux tab/pane |
| `size` | `40%` | deprecated — ignored now that panes open side-by-side in a dedicated window |
| `focus` | settings or `false` | focus the pane vs. stay in pi |
| `keepPaneOpen` | settings or `true` | keep the dead pane for review |
| `timeoutSeconds` | settings or `1800` | kill the subagent after N seconds |

## Security

Running a subagent spawns a `pi` subprocess with a delegated system prompt, model, and
tools. Project-local agents (`.pi/agents/*.md`) are repo-controlled; they load only with
`agentScope: "both"` or `"project"`, and you're prompted before they run (unless
`confirmProjectAgents: false`). Only enable project agents in repos you trust.
