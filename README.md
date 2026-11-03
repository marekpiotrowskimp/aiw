# aiw — "contract before code" for AI coding agents (iOS / Swift)

A personal workflow for **Claude Code** and **OpenCode** that substantially reduces the two most common problems of working with an AI agent:

1. **Regressions.** The agent breaks working features along the way.
2. **Bugs in new code.** The agent delivers a feature that "looks fine" but fails on edge cases. Sometimes it even shows green tests because it quietly changed the tests instead of the code.

The workflow is meant for people who **don't always have time to read all the code an agent generates**, yet still need to be sure it works.

> The commands, generated specs and tool messages are in Polish.

---

## Why

A typical session with an agent goes like this: you ask for a feature, the agent writes code, says "done, tests pass", and you either read every line (losing the benefit of AI) or take its word for it (risking bugs in production).

Experience from other teams and research (see [Sources](#sources)) leads to a few conclusions:

- **The agent needs a deterministic way to check its own work.** According to Anthropic this is the single most effective practice.
- **Instructions in prompts and `CLAUDE.md` are requests, not guarantees.** The agent sometimes skips them. Rules that must hold have to be enforced in code (hooks).
- **Agents can game tests**: they change assertions, add `skip`, hard-code results. The cheapest protection is read-only tests plus an explicit "this can't be done, I'm reporting a problem" path for the agent.
- **A generic "write tests / do TDD" in the prompt can increase regressions.** What helps is specific context: which tests protect the change at hand.

## Core idea

> **You check the "what" (the contract). The machine checks the "how" (the code).**

Reading 500 lines of code takes about 30 minutes. Reading 10 acceptance criteria and test names takes 3–5 minutes. The latter can always be done, even under time pressure. Everything else is enforced by automation the agent cannot bypass.

```
 /spec ──────────────► You: 3–5 min ──► /implement ─────────────► /audit ──────────────► /finish
 agent writes:         read the spec    tests are LOCKED          independent            report,
 • the spec            and the          agent cannot finish       reviewer in a          unlock,
 • tests of current    "criterion →     until the build and all   separate context:      proposed
   behavior (green)    test → assertion" tests pass               "do you need to read   commits
 • tests of new        table                                      the diff? YES/NO"
   criteria (red)
```

## Benefits

| Benefit | How |
|---|---|
| **Fewer regressions** | Before the agent changes existing code, it records the current behavior in characterization tests. At the end the whole suite must pass. |
| **Tests don't lie** | Approved tests are locked. Edit attempts are rejected, and changes made through a workaround are reverted automatically. |
| **The agent can't declare success prematurely** | Tests are run by a hook, not by the agent. The agent cannot finish until they are green. |
| **Honesty instead of workarounds** | The agent has an explicit emergency exit (`aiw blocker`): it reports the problem instead of masking it. |
| **You know when you must read the code** | The audit and a list of high-risk paths (auth, payments, migrations, `.pbxproj`) tell you directly whether this diff needs your attention. |
| **Less review time** | You read the contract (minutes), not the implementation (tens of minutes). |
| **Zero impact on the team** | Nothing goes into the repository: no `CLAUDE.md`, `.claude/` or `.gitignore`. Everyone decides for themselves whether to work this way. |
| **Vendor independence** | The same commands and rules work in Claude Code and OpenCode, with any model. Task state is shared. |

---

## Requirements

- macOS with Xcode (`xcodebuild`) and `git`
- `jq` (built into newer macOS or `brew install jq`)
- Claude Code and/or OpenCode
- Optional: SwiftLint (lint after every edit), [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) if the project already uses it (view tests)

## Installation

```bash
git clone https://github.com/marekpiotrowskimp/aiw.git ~/Projects/aiw
cd ~/Projects/aiw
./install.sh
```

Then restart Claude Code / OpenCode. Uninstall with `./uninstall.sh`; it removes everything except your project data.

The installer only touches your home directory:

| What | Where |
|---|---|
| Tool and hooks | `~/.claude/ai-workflow` → symlink to this repo |
| Claude Code commands | `~/.claude/commands/{spec,implement,audit,finish}.md` (symlinks) |
| Claude Code hooks | added to `~/.claude/settings.json` (with a backup) |
| OpenCode commands | `~/.config/opencode/commands/*.md` (generated) |
| OpenCode plugin | `~/.config/opencode/plugins/aiw.js` (symlink) |
| Config, specs, state | `~/.claude/ai-workflow-data/projects/<project>/` |

The hooks are global but **inactive** outside the `/implement` stage. Otherwise they do nothing and don't slow you down.

---

## How to work — step by step

### 1. `/spec <task description>` — the contract

```
/spec add Face ID login with a PIN fallback after 3 failed attempts
```

The agent:
- on first use in a project detects the scheme and simulator and creates a local config,
- reads the affected code and its call sites,
- writes the spec: acceptance criteria (Given/When/Then), edge cases, an **"Out of scope — MUST NOT change"** section, risk level,
- writes **characterization tests** of existing behavior, which must be **green**,
- writes **tests for the new criteria**, which must be **red for the right reason**,
- **does not implement** the feature.

**Your role (the one step you must not skip):** read the "criterion → test → what the assertion checks" table and ask yourself one question: *"If these tests pass, does the feature work the way I want?"*. If not, ask for changes while still in this phase.

### 2. `/implement` — implementation against a locked contract

Running the command means you accept the contract. From then on:
- test files are **locked**,
- the agent **cannot finish** until the build and all tests pass,
- if a test turns out to be wrong, the agent raises a blocker and stops instead of working around it,
- after N failed attempts (6 by default) the task is marked **FAILED** and the agent stops going in circles.

Running `/implement` again (e.g. after resolving a blocker) resumes work with a fresh attempt budget.

### 3. `/audit` — an independent reviewer

Runs in a separate context, without the author's conversation history. It checks:
- conformance with the spec,
- out-of-scope changes,
- regressions for other callers,
- workarounds,
- iOS pitfalls: `@MainActor`, reference cycles, `Task`, view lifecycle.

It returns (in Polish):

```
WERDYKT: OK | DO POPRAWY | STOP                       (VERDICT: OK | NEEDS FIXES | STOP)
CZY MUSISZ CZYTAĆ DIFF: NIE | TAK — <files and why>   (DO YOU NEED TO READ THE DIFF: NO | YES)
```

### 4. `/finish` — wrap-up

Unlocks the tests, shows a report (test result, high-risk files, any blockers) and proposes a split into small commits. **It commits nothing unless you ask.**

### When to read the code anyway

| Risk level | Examples | Your check |
|---|---|---|
| Low | UI, copy, isolated new modules | spec + test table |
| Medium | business logic, changes to existing features | spec + test table + `/audit` verdict |
| High | authorization, payments, Keychain, data migrations, `.pbxproj`, entitlements | **always read the diff of the listed files** |

What counts as "high risk" is decided by the config (`AIW_HIGH_RISK_GLOBS`), not by the agent.

---

## Project configuration

The file `~/.claude/ai-workflow-data/projects/<project>/config.sh` (created on the first `/spec`):

| Variable | Meaning |
|---|---|
| `AIW_TEST_CMD` | build + tests, e.g. `xcodebuild test -workspace App.xcworkspace -scheme App -destination 'platform=iOS Simulator,name=iPhone 16' -quiet` |
| `AIW_TEST_GLOBS` | which files are tests (locked during `/implement`) |
| `AIW_HIGH_RISK_GLOBS` | paths whose diff you must read |
| `AIW_LINT_CMD` | optional linter after every `.swift` edit |
| `AIW_MAX_STOP_BLOCKS` | how many times the agent can be sent back for fixes |

In a large project narrow `AIW_TEST_CMD` (a separate test plan, `-only-testing:`), because it runs at the end of every turn during `/implement`.

Helper commands (prefix them with `!` inside a session):

```bash
~/.claude/ai-workflow/bin/aiw status    # phase, test result, blockers
~/.claude/ai-workflow/bin/aiw report    # report of changes since the start of the task
```

---

## How it works under the hood

| Mechanism | Claude Code | OpenCode |
|---|---|---|
| Commands | `~/.claude/commands/*.md` | generated from the same files (`context: fork` → `subtask: true`) |
| Blocking test edits | `PreToolUse` hook → deny | `tool.execute.before` plugin → exception (also `apply_patch`) |
| Detecting and reverting test changes | checksums + snapshot at the end of a turn | the same |
| "You can't finish without green tests" | the `Stop` hook blocks finishing | after `session.idle` the plugin runs the tests and on failure sends the agent a prompt |
| Linter after edits | `PostToolUse` hook | result appended to the tool output |

All rules live in `hooks/*.sh`. The OpenCode plugin only translates events and calls the same scripts, so both platforms behave the same.

```
bin/aiw            tool: init, begin, lock, test, report, finish, blocker
hooks/             rules (shared by both tools)
commands/          /spec /implement /audit /finish (single source)
opencode/aiw.js    OpenCode adapter
templates/         config.sh and the spec template
```

## Troubleshooting

**`/implement` didn't lock the tests and the agent asks you to run `aiw lock` manually.** Each command allows its own `aiw` call in `allowed-tools`. Without that permission Claude Code in auto mode does not run the `` !`…` `` command itself and asks the agent to do it instead. The hook rightly blocks `aiw lock` for the agent, so nothing happens. Check that `~/.claude/commands/implement.md` points to the current version from the repo and that no `deny`/`ask` rule in your permission settings covers `aiw`. Quick fix: `! ~/.claude/ai-workflow/bin/aiw lock`, then run `/implement` again.

**The `/spec`, `/implement`… commands disappeared from Claude Code / OpenCode.** The installation consists of symlinks to the repo directory. After moving or renaming the repo they point nowhere. Run `./install.sh` from the new location and the symlinks are updated.

**After renaming a project aiw "doesn't remember" the spec.** Project data is tied to its path (`~/.claude/ai-workflow-data/projects/<path-with-dashes>/`). Rename that directory to match the new project path.

## Limitations — honestly

- **A bad contract = green but wrong.** If the spec and tests are wrong, everything passes. That's why step 1 is mandatory.
- **Blocking bash commands is a heuristic.** The last line of defense is the test checksum check at the end of every turn. Modified tests are restored.
- **This does not replace CI or team code review.** It is an extra layer before you push.
- **OpenCode has no equivalent of the Stop hook.** The agent finishes its turn first and only then gets a prompt with the errors. The adapter was tested on OpenCode 2.0.20; tool names may change in newer versions.
- **A full `xcodebuild test` is slow.** Narrow the test scope in the config.

---

## Sources

The workflow is based on the materials below. Some are research papers, some are tool documentation, and some are practitioners' experience. Treat the latter as observations rather than hard evidence.

### Research

- [TDAD: Test-Driven Agentic Development (arXiv, 2026)](https://arxiv.org/abs/2603.17973) — an unassisted agent broke ~6.5 tests per fix on average. A bare "do TDD" in the prompt **increased** regressions. Pointing the agent to the tests related to the changed code reduced them by about 70%. Basis for characterization tests and running the full suite at the end of a turn.
- [EvilGenie: A Reward Hacking Benchmark (arXiv)](https://arxiv.org/abs/2511.21654) — documents how agents "cheat" tests (editing test files, hard-coding results) and how to detect it. Basis for test locking and checksums.
- [The Verification Horizon: No Silver Bullet for Coding Agent Rewards (arXiv)](https://arxiv.org/pdf/2606.26300) — limits of automatic verification of agent work. Rationale for having a human approve the contract.
- [AIDev: Studying AI Coding Agents on GitHub (arXiv)](https://arxiv.org/html/2602.09185v1) — a dataset of over 33k agent-authored pull requests from about 2.8k repositories.
- [What 33,000 Agentic Pull Requests Reveal](https://codex.danielvaughan.com/2026/04/18/empirical-research-agentic-pull-requests-codex-cli/) — practical takeaways from that data: small, focused changes verified by CI are accepted more often. Basis for the small-commit proposal in `/finish`.

### Tool documentation

- [Claude Code — Best Practices](https://code.claude.com/docs/en/best-practices.md) — Anthropic's most important practice: give the agent a way to check its own work (tests, build, screenshot).
- [Claude Code — Power user tips](https://support.claude.com/en/articles/14554000-claude-code-power-user-tips) — verification as the practice with the biggest impact on output quality.
- [Claude Code — Hooks](https://code.claude.com/docs/en/hooks.md) — `PreToolUse`, `PostToolUse` and `Stop`, and how to block actions. The technical basis for rule enforcement.
- [Claude Code — Skills / commands](https://code.claude.com/docs/en/skills.md) — `/…` commands, `$ARGUMENTS`, injecting command output with `` !`…` ``, `context: fork` for an audit in a separate context.
- [Claude Code — Memory (CLAUDE.md)](https://code.claude.com/docs/en/memory.md) — CLAUDE.md is context, not enforced configuration; hooks are for blocking actions. Also explains how to keep personal settings out of the repository.
- [OpenCode — Commands](https://opencode.ai/docs/commands/) — OpenCode command format (`$ARGUMENTS`, `` !`…` ``, `subtask`).
- [OpenCode — Plugins](https://opencode.ai/docs/plugins/) — the `tool.execute.before/after` and `session.idle` events the adapter relies on.
- [OpenCode — SDK](https://opencode.ai/docs/sdk/) — `session.prompt` and `tui.showToast`, used to send the agent back for fixes.
- [OpenCode — Skills](https://opencode.ai/docs/skills/) — explains why the workflow uses commands rather than skills: in OpenCode skills are invoked by the model, not the user.
- [Cursor — Reviewing and testing](https://cursor.com/learn/reviewing-testing) — small, semantic commits; agent code is held to the same standards as human code; typical risks are missing edge cases and duplicated logic.

### Practitioners' experience

- [Why "Always Run Tests" in AGENTS.md Makes Things Worse](https://codex.danielvaughan.com/2026/06/05/why-always-run-tests-agents-md-makes-things-worse/) — why a generic "run the tests" instruction in the agent file doesn't work.
- [The 4 hooks every Claude Code project needs](https://pub.towardsai.net/the-4-hooks-every-claude-code-project-needs-665f8d610f8b) — CLAUDE.md instructions are probabilistic, hooks are deterministic.
- [Claude Code deep dive: hooked](https://medium.com/@the.gigi/claude-code-deep-dive-hooked-8492c9b5c9fb) — the agent skipped tests despite CLAUDE.md rules, so enforcement moved into hooks.
- [Claude Code hooks — practical guide (wmedia)](https://wmedia.es/en/writing/claude-code-hooks-practical-guide) — a Stop hook that runs tests and protection against an infinite loop. Basis for the attempt limit.
- [Claude Code Hooks Examples (morphllm)](https://www.morphllm.com/claude-code-hooks-examples) — hooks must be fast; run related tests instead of the whole suite after every save. Basis for caching the test result.
- [Claude Code TDD workflow (stacknotice)](https://stacknotice.com/blog/claude-code-tdd-workflow-2026) — red-green-refactor combined with hooks.
- [Claude Code Best Practices: 3 Lessons from 400,000 Sessions (Analytics Vidhya)](https://www.analyticsvidhya.com/?p=256782) — the "verification ladder": from a check in the prompt to a Stop hook that blocks finishing.
- [Reward hacking — guardrails for AI agents (noqta)](https://noqta.tn/en/blog/reward-hacking-ai-agents-specification-gaming-guardrails-2026) — read-only tests plus the option to report "task infeasible" greatly reduce cheating. Basis for `aiw blocker`.
- [Working method for AI coding agents (SpotDev)](https://www.spotdev.co.uk/blog/working-method-for-ai-coding-agents) — tests committed before the implementation, and a warning when a test changes in the same commit as the code.
- [Should You Still Review Your AI Agent's Code?](https://agentsroom.dev/blog/should-you-review-ai-agent-code) — matching review depth to the risk of the change. Basis for the risk levels.

### Spec-driven development

- [GitHub Spec Kit](https://github.com/github/spec-kit) — a reference implementation of the approach: spec → plan → tasks → implementation.
- [Spec-Driven Development in 2026: The Complete Guide](https://codemyspec.com/blog/spec-driven-development) — an overview of SDD tools and stages.
- [A Practical Guide to Spec-Driven Development with AI (Design News)](https://www.designnews.com/embedded-systems/a-practical-guide-to-spec-driven-development-with-ai) — the engineer's role shifts from steering code generation to verifying against requirements.
- [Spec-Driven Development: The Future of AI Coding or Waterfall 2.0?](https://alexcloudstar.com/blog/spec-driven-development-2026/) — a critical look at the overhead of SDD. That's why the spec here is short and mandatory only for criteria and tests.

### Engineering classics

- [Characterization test (Wikipedia)](https://en.wikipedia.org/wiki/Characterization_test) — Michael Feathers' technique (*Working Effectively with Legacy Code*): before changing code, capture its current behavior in tests. Basis for regression protection in `/spec`.

## License

MIT — see [LICENSE](LICENSE).
