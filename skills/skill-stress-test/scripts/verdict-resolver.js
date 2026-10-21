#!/usr/bin/env node
// Invariant: --report <path> required; prints exactly one headline verdict token to stdout.
// Invariant: precedence is BLOCKED_NO_TARGET > VALIDATION_INCONCLUSIVE > HARNESS_GAP > PLUGIN_DRIFT > VALIDATION_CLEAN.
// Invariant: Plan 1 only emits VALIDATION_CLEAN, PLUGIN_DRIFT, VALIDATION_INCONCLUSIVE. HARNESS_GAP and BLOCKED_NO_TARGET land in Plan 4 and Bottom Line respectively.

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
  stderr.write(`verdict-resolver: ${msg}\n`);
  exit(code);
}

const args = parseArgs(argv.slice(2));
if (!args.report) fail("--report required");

const report = JSON.parse(readFileSync(args.report, "utf8"));
// Invariant: layers.static.verdict is already the worst across plugin_findings + per_skill — set by layer-static.sh.
const staticLayer = report.layers?.static;

let headline;
if (!staticLayer || staticLayer.verdict === "INCONCLUSIVE") {
  headline = "VALIDATION_INCONCLUSIVE";
} else if (staticLayer.verdict === "ACCEPT") {
  headline = "VALIDATION_CLEAN";
} else if (["ACCEPT_WITH_MINOR", "REJECT_IMPORTANT", "REJECT_CRITICAL"].includes(staticLayer.verdict)) {
  headline = "PLUGIN_DRIFT";
} else {
  headline = "VALIDATION_INCONCLUSIVE";
}

stdout.write(headline);
