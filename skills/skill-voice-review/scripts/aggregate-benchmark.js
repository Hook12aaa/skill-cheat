#!/usr/bin/env node
// Invariant: consumes a JSONL file of run-eval outputs tagged with a `ref` field; emits one aggregate JSON object to stdout.
// Invariant: refs are the literal strings "baseline" and "candidate"; any other ref is a schema violation.

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

function fail(msg, code = 65) {
  stderr.write(`aggregate-benchmark: ${msg}\n`);
  exit(code);
}

function mean(nums) {
  if (nums.length === 0) return 0;
  return nums.reduce((a, b) => a + b, 0) / nums.length;
}

function stddev(nums) {
  if (nums.length < 2) return 0;
  const m = mean(nums);
  return Math.sqrt(mean(nums.map((n) => (n - m) ** 2)));
}

function stats(runs) {
  const passed = runs.filter((r) => r.triggered).length;
  const tokens = runs.map((r) => r.totalTokens ?? 0);
  const durations = runs.map((r) => r.durationMs ?? 0);
  return {
    runs: runs.length,
    passRate: runs.length === 0 ? 0 : passed / runs.length,
    meanTokens: mean(tokens),
    stddevTokens: stddev(tokens),
    meanDurationMs: mean(durations),
    stddevDurationMs: stddev(durations),
  };
}

const args = parseArgs(argv.slice(2));
if (!args.runs) fail("--runs <jsonl-file> required", 64);

const lines = readFileSync(args.runs, "utf8").split("\n").filter((l) => l.trim());
const all = lines.map((l, i) => {
  try { return JSON.parse(l); }
  catch { fail(`line ${i + 1} is not valid JSON`); }
});
for (const r of all) {
  if (r.ref !== "baseline" && r.ref !== "candidate") {
    fail(`unexpected ref: ${r.ref}`);
  }
}

const baseline = stats(all.filter((r) => r.ref === "baseline"));
const candidate = stats(all.filter((r) => r.ref === "candidate"));

stdout.write(JSON.stringify({
  baseline,
  candidate,
  delta: {
    passRate: candidate.passRate - baseline.passRate,
    meanTokens: candidate.meanTokens - baseline.meanTokens,
    meanDurationMs: candidate.meanDurationMs - baseline.meanDurationMs,
  },
}) + "\n");
