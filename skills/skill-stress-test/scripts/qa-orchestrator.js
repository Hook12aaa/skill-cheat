#!/usr/bin/env node
// Invariant: writes <target>/.skill-cheat-qa/runs/<run-id>/{manifest.json, static-findings.json, report.json}.
// Invariant: prints exactly one line to stdout: "VERDICT: <token>". Non-zero exit on BLOCKED_NO_TARGET.

import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { argv, cwd, exit, stderr, stdout } from "node:process";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILL_ROOT = resolve(__dirname, "..");

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

function runShell(cmd, args, opts = {}) {
  const r = spawnSync(cmd, args, { encoding: "utf8", ...opts });
  if (r.status !== 0) {
    return { ok: false, stdout: r.stdout, stderr: r.stderr, status: r.status };
  }
  return { ok: true, stdout: r.stdout, stderr: r.stderr };
}

const args = parseArgs(argv.slice(2));
const pluginArg = args.plugin || cwd();

const harnessRoot = process.env.CLAUDE_PLUGIN_ROOT;
if (harnessRoot && resolve(pluginArg) === resolve(harnessRoot)) {
  stderr.write(
    "qa-orchestrator: refusing to audit the harness root via CLAUDE_PLUGIN_ROOT; pass --plugin <path> to a different target\n"
  );
  stdout.write("VERDICT: BLOCKED_NO_TARGET\n");
  exit(1);
}

const connectScript = resolve(SKILL_ROOT, "scripts", "connect-plugin.sh");
const connect = runShell("bash", [connectScript, "--plugin", pluginArg]);
if (!connect.ok) {
  stderr.write(connect.stderr || "");
  stdout.write("VERDICT: BLOCKED_NO_TARGET\n");
  exit(1);
}
const manifest = JSON.parse(connect.stdout);
const runId = manifest.run_id;
const runsParent = resolve(manifest.target.path, ".skill-cheat-qa", "runs");
mkdirSync(runsParent, { recursive: true });
const runDir = resolve(runsParent, runId);
mkdirSync(runDir, { recursive: false });
writeFileSync(resolve(runDir, "manifest.json"), JSON.stringify(manifest, null, 2));

const staticScript = resolve(SKILL_ROOT, "scripts", "layer-static.sh");
const staticRun = runShell("bash", [staticScript, "--target", manifest.target.path]);
if (!staticRun.ok) {
  stderr.write(staticRun.stderr || "");
  stdout.write("VERDICT: VALIDATION_INCONCLUSIVE\n");
  exit(1);
}
writeFileSync(resolve(runDir, "static-findings.json"), staticRun.stdout);

const reportPath = resolve(runDir, "report.json");
const writer = runShell("node", [
  resolve(SKILL_ROOT, "scripts", "report-writer.js"),
  "--manifest", resolve(runDir, "manifest.json"),
  "--static",   resolve(runDir, "static-findings.json"),
  "--output",   reportPath
]);
if (!writer.ok) {
  stderr.write(writer.stderr || "");
  stdout.write("VERDICT: VALIDATION_INCONCLUSIVE\n");
  exit(1);
}

const resolver = runShell("node", [
  resolve(SKILL_ROOT, "scripts", "verdict-resolver.js"),
  "--report", reportPath
]);
if (!resolver.ok) {
  stderr.write(resolver.stderr || "");
  stdout.write("VERDICT: VALIDATION_INCONCLUSIVE\n");
  exit(1);
}
const headline = resolver.stdout.trim();

const finalReport = JSON.parse(readFileSync(reportPath, "utf8"));
finalReport.verdict = headline;
writeFileSync(reportPath, JSON.stringify(finalReport, null, 2));

stdout.write(`VERDICT: ${headline}\n`);
