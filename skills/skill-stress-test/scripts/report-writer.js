#!/usr/bin/env node
// Invariant: writes a JSON file matching report-schema.json with verdict="PENDING".
// Invariant: --manifest --static --output all required; exit 64 on bad args.
// Invariant: behavioral/e2e/evolutionary layers are emitted as null when their input is absent.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { argv, exit, stderr } from "node:process";

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
  stderr.write(`report-writer: ${msg}\n`);
  exit(code);
}

const args = parseArgs(argv.slice(2));
if (!args.manifest || !args.static || !args.output) {
  fail("--manifest --static --output all required");
}

const manifest = JSON.parse(readFileSync(args.manifest, "utf8"));
const staticLayer = JSON.parse(readFileSync(args.static, "utf8"));

const report = {
  verdict: "PENDING",
  manifest,
  cost: { token_estimate: 0, token_actual: 0, duration_ms: 0 },
  layers: {
    static: staticLayer,
    behavioral: null,
    e2e: null,
    evolutionary: null
  },
  ownership: {
    plugin_author_actions: [],
    skill_cheat_actions: []
  }
};

mkdirSync(dirname(args.output), { recursive: true });
writeFileSync(args.output, JSON.stringify(report, null, 2));
