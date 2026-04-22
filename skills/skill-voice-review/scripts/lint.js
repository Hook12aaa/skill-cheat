#!/usr/bin/env node
// Invariant: stdin/argv in, single JSON object on stdout, exit 0 on success, non-zero on detector error (not on rule failure).

import { readFileSync } from "node:fs";
import { argv, exit, stderr, stdout } from "node:process";

const detectors = {
  "yaml-frontmatter": detectYamlFrontmatter,
  "section-order": detectSectionOrder,
  "cross-reference": detectCrossReference,
};

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

function fail(msg) {
  stderr.write(`lint.js: ${msg}\n`);
  exit(2);
}

function emitFindings(findings) {
  stdout.write(JSON.stringify({ findings }));
  stdout.write("\n");
}

function detectYamlFrontmatter(_skillText, _config) {
  return [];
}

function detectSectionOrder(_skillText, _config) {
  return [];
}

function detectCrossReference(_skillText, _config) {
  return [];
}

const args = parseArgs(argv.slice(2));
if (!args.detector) fail("missing --detector");
if (!args.skill) fail("missing --skill");

const detector = detectors[args.detector];
if (!detector) fail(`unknown detector: ${args.detector}`);

const skillText = readFileSync(args.skill, "utf8");
const config = args.config ? JSON.parse(args.config) : {};

try {
  emitFindings(detector(skillText, config));
} catch (err) {
  fail(`detector ${args.detector} threw: ${err.message}`);
}
