#!/usr/bin/env node
// Invariant: accepts --skill-path --query --skill-name [--mock-stream-file | --model]; emits one JSON object to stdout.
// Invariant: --mock-stream-file reads a pre-recorded JSONL stream instead of spawning claude; never used in production runs.
// Invariant: triggered=true iff the stream contains a content_block_start whose tool_use input name matches --skill-name.

import { readFileSync } from "node:fs";
import { argv, exit, stderr, stdout } from "node:process";

function parseArgs(args) {
  const out = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--")) {
      out[args[i].slice(2)] = args[i + 1];
      i++;
    }
  }
  return out;
}

function fail(msg, code = 64) {
  stderr.write(`run-eval: ${msg}\n`);
  exit(code);
}

function analyseStream(lines, skillName) {
  let triggered = false;
  let durationMs = 0;
  let totalTokens = 0;
  let events = 0;
  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;
    let ev;
    try { ev = JSON.parse(line); } catch { continue; }
    events += 1;
    if (ev.type === "stream_event"
        && ev.event?.type === "content_block_start"
        && ev.event.content_block?.type === "tool_use"
        && ev.event.content_block.input?.name === skillName) {
      triggered = true;
    }
    if (ev.type === "result" && ev.subtype === "success") {
      durationMs = ev.duration_ms ?? 0;
      totalTokens = ev.total_tokens ?? 0;
    }
  }
  return { triggered, durationMs, totalTokens, streamEvents: events };
}

const args = parseArgs(argv.slice(2));
for (const required of ["skill-path", "query", "skill-name"]) {
  if (!args[required]) fail(`--${required} required`);
}

let streamLines;
let mock = false;
if (args["mock-stream-file"]) {
  mock = true;
  streamLines = readFileSync(args["mock-stream-file"], "utf8").split("\n");
} else {
  fail("production mode not implemented in Plan 5 Task 9; use --mock-stream-file. Task 10 wires real claude subprocess.", 65);
}

const analysis = analyseStream(streamLines, args["skill-name"]);

stdout.write(JSON.stringify({
  skillName: args["skill-name"],
  query: args.query,
  ...analysis,
  mock,
}) + "\n");
