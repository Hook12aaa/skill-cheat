# skill-cheat

A Claude Code plugin that scaffolds skills in the imperative, gate-driven, contract-first style.

**Runs standalone. No plugin dependencies.** Host-tool prerequisites: `bash`, `openssl`, `node`, `graphviz` (`dot`), `jq`.

## Install

```
/plugin marketplace add /path/to/skill_cheat
/plugin install skill-cheat
```

## Use

Any of these invocations kicks off the 5-stage pipeline:

- Type `/skill-scope` to start explicitly.
- Say "I want to build a skill for X" — the UserPromptSubmit hook reminds Claude to start the pipeline.

## Stages

1. `/skill-scope` — lock name, triggers, verdicts, Anti-Pattern.
2. `/skill-design` — write HARD-GATEs, Core Principle, flow, checklist; emit Integrity Block + SHA-256.
3. `/skill-author` — fill the skill body; verify Integrity Block unchanged.
4. `/skill-voice-review` — mechanical lint + voice-reviewer subagent; REJECT or ACCEPT.
5. `/skill-scaffold` — emit the plugin tree at the target path.

## Principles

- Contract-first, library-last.
- Imperative voice, ALL-CAPS verdicts, zero hedges.
- `.md` + `.js` + `.sh` + `.json` only.
- Structural distrust — no agent both produces and approves its own work.
- Self-contained — no plugin dependencies.
