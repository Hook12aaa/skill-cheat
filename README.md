# skill-cheat

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-44%20passing-brightgreen)](#tests)
[![Version](https://img.shields.io/badge/version-0.1.0-blue)](#)

> Five gated stages. Twenty-one lint rules. Skills that actually hold up.

---

## Why I built this

If you've looked at some of my Claude Code skills, you've probably noticed they're a bit more structured than what you'd typically see in a GitHub repo. That's not an accident — it came from spending a lot of time inside [superpowers](https://github.com/nicholasgriffintn/superpowers) and learning how it works. Things like SHA fingerprinting, treating artifacts as typed contracts, separating the agent that writes from the agent that reviews. That stuff stuck with me.

As I built skills for my own projects — the model trainer pipeline, the auto-discover experiment runner, things like that — I kept noticing the same pattern. I'd try something out, learn what worked, come back and try to capture it as a skill. Not building a system top-down, but discovering the pipeline by running experiments first and then asking: can I turn this into something repeatable?

That's how skill-cheat got created. I kept typing the same scaffolding at the top of every skill. The same all-caps verdicts. The same anti-hedge reminders. The same HARD-GATE blocks. By the time I had eight skills, I had a tacit anatomy I was applying by reflex but never as a contract. So I built the contract.

I call it skill-cheat because honestly, it feels like cheating. The level of quality that comes out of the pipeline — skills that hold their voice under load, that don't drift across sessions, that lint clean against twenty-one rules grounded in actual published practice — it's not what you'd expect from a scaffolding tool.

There have been multiple iterations to get here. If you're thinking about trying it, my suggestion is simple: install it, point it at a skill you want to build, and have some fun with it.

---

## Install

```bash
/plugin marketplace add /path/to/skill-cheat
/plugin install skill-cheat@skill-cheat-local
```

**Requirements on `PATH`:** `bash`, `openssl`, `node`, `jq`, `dot` (graphviz).

Open a session. Say "I want to build a skill for X" — or type `/skill-scope` to start explicitly. The `UserPromptSubmit` hook detects skill-authoring intent and kicks off the pipeline.

---

## The five stages

```mermaid
flowchart LR
    A[/skill-scope/] --> B[/skill-design/]
    B --> C[/skill-author/]
    C --> D[/skill-voice-review/]
    D -->|REJECT| C
    D -->|ACCEPT| E[/skill-scaffold/]

    classDef stage fill:#1f1a14,stroke:#c98c3c,color:#f5ecd8;
    class A,B,C,D,E stage;
```

| Command | What happens | What you do |
|---|---|---|
| `/skill-scope` | Name, triggers, verdicts, Anti-Pattern locked. Emits `scope.md`, `scope.json`, and an eval-set skeleton. | Confirm the scope is right. |
| `/skill-design` | HARD-GATEs, Core Principle, flow diagram, checklist. SHA-256 Integrity Block locks the design. | Approve the design. |
| `/skill-author` | Body gets filled in. Integrity Block re-verified — edit a locked field and the pipeline halts. That's the point. | Watch it work. |
| `/skill-voice-review` | 21-rule mechanical lint, then a reviewer subagent that never saw the author's work. REJECT or ACCEPT. | Fix what it flags, or argue the rule. |
| `/skill-scaffold` | Emits the plugin tree at the target path. The `evals/` directory travels with the skill. | Wire it into your plugin. |

You approve at three gates: the scope, the design, and the voice-review verdict. Everything in between is the pipeline doing its job.

---

## How it works under the hood

**Every skill is a typed contract.** Frontmatter is validated. Sections are typed. Voice is mechanical. The lint engine carries 21 rules dispatched through 7 detectors (`grep-denylist`, `hard-gate-span`, `yaml-frontmatter`, `bash-syntax`, `regex-line`, `find-extensions`, `digraph-fence`). Every rule is declarative JSON — new rules are JSON, not code.

**Lint runs before eval.** Static deterministic checks first. Lint failures are cheap, repeatable, and bound by a known rule set. This is shift-left applied to LLM artifacts.

**Two kinds of rule.** `skill-shape` rules apply universally — every Claude Code skill should hold these. `plugin-policy` rules are skill-cheat's local opinion. Cross-plugin mode filters the policy rules out so your signal on someone else's plugin stays clean.

**The design is tamper-evident.** `/skill-design` writes a SHA-256 sidecar. `/skill-author` re-verifies it. Edit a locked field and the next stage halts. Authoring drift across stages costs you a re-derivation. This was one of the patterns I picked up from superpowers and it's been one of the most valuable.

**No agent grades its own work.** Author and reviewer are separate subagents with separate prompts. The reviewer sees only the artifact, never the author's reasoning. Same principle as [Fagan inspections](https://en.wikipedia.org/wiki/Fagan_inspection) from 1976 — separation is the constraint, not the format.

---

## Cross-plugin validation

You can also point skill-cheat at any Claude Code plugin and stress-test it:

```bash
node skills/skill-stress-test/scripts/qa-orchestrator.js --plugin /path/to/plugin
```

Output lands at `<target>/.skill-cheat-qa/runs/<run-id>/report.json` and a verdict on stdout:

| Verdict | Meaning |
|---|---|
| `VALIDATION_CLEAN` | Every SKILL.md passed. |
| `PLUGIN_DRIFT` | At least one SKILL.md triggered a finding. |
| `VALIDATION_INCONCLUSIVE` | Could not complete (no skills, depth violation, symlink). |
| `BLOCKED_NO_TARGET` | No plugin resolved. |

I ran this against 47 real plugins from my local cache — 34 PLUGIN_DRIFT, 13 INCONCLUSIVE (correctly routed), 0 false CLEAN, 0 crashes. The lint engine's signal-to-noise on foreign plugins is bounded by skill-shape rules only.

---

## On HARD-GATE syntactic enforcement

One thing I want to address directly. Anthropic's prompt-engineering guidance treats `MUST` / `NEVER` / `ALWAYS` blocks as a yellow flag — their reasoning is that readers pattern-match nag text and tune it out.

I think that's correct for human readers and wrong for LLM readers. An LLM following a multi-screen skill needs a syntactic anchor — a token shape that says "this is the non-negotiable line." The `<HARD-GATE>` block is that anchor. It's the LLM analogue of an `assert` statement: ugly, repetitive, deliberately interruptive, and exactly what you want when correctness depends on the assertion firing.

This is one of the positions skill-cheat takes. If you disagree, fork the rules — the rule shape is portable.

---

## Tests

```bash
bash tests/run-tests.sh
```

44 shell tests across hooks, lint primitives, lint end-to-end, integration, QA harness, integrity, and pipeline shape. Every hook and script has a test. 21 bad fixtures (one per lint rule) and a minimal good fixture.

---

## Documentation

- **[DEVELOPMENT.md](DEVELOPMENT.md)** — how this project was built: the plan sequence, design specs, stress-test findings, and the decisions behind each phase.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — setup, conventions, and the lint rule shape if you want to add rules.
- **[docs/field-manual/](docs/field-manual/)** — comprehensive reference for every skill, rule, and script.
- **[docs/flow-atlas/](docs/flow-atlas/)** — architecture diagrams.
- **[docs/development/](docs/development/)** — the raw plans, specs, and findings from the build.

---

## Licence

MIT. See [LICENSE](LICENSE). Use it. Fork it. Build on it.
