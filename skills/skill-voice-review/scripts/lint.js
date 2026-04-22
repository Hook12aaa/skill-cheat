#!/usr/bin/env node
// Invariant: stdin/argv in, single JSON object on stdout, exit 0 on success, non-zero on detector error (not on rule failure).

import { readFileSync } from "node:fs";
import { argv, exit, stderr, stdout } from "node:process";

const detectors = {
  "yaml-frontmatter": detectYamlFrontmatter,
  "section-order": detectSectionOrder,
  "cross-reference": detectCrossReference,
  "hard-gate-span": detectHardGateSpan,
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

function detectYamlFrontmatter(skillText, config) {
  const findings = [];
  const lines = skillText.split("\n");

  const firstDash = lines.findIndex((l) => l.trim() === "---");
  if (firstDash === -1) {
    return [{ location: null, message: "frontmatter absent", excerpt: null }];
  }
  const secondDash = lines.findIndex((l, i) => i > firstDash && l.trim() === "---");
  if (secondDash === -1) {
    return [{ location: null, message: "frontmatter absent", excerpt: null }];
  }

  const frontmatterLines = lines.slice(firstDash + 1, secondDash);
  const fields = {};
  for (const line of frontmatterLines) {
    const colonIdx = line.indexOf(":");
    if (colonIdx === -1) continue;
    const key = line.slice(0, colonIdx).trim();
    const value = line.slice(colonIdx + 1).trim();
    fields[key] = value;
  }

  const required = config["required-fields"] ?? [];
  for (const field of required) {
    if (fields[field] === undefined || fields[field] === "") {
      findings.push({ location: null, message: `frontmatter missing required field: ${field}`, excerpt: null });
    }
  }

  const description = fields["description"] ?? "";

  if (config["description-contains-trigger"]) {
    const hasTrigger = /\/[a-z][\w-]*/i.test(description) || /\btrigger\b/i.test(description);
    if (!hasTrigger) {
      findings.push({ location: null, message: "description does not name a trigger", excerpt: description });
    }
  }

  if (config["description-contains-verdict"]) {
    const hasVerdict = /\b[A-Z][A-Z0-9]{3,}(_[A-Z0-9]+)*\b/.test(description);
    if (!hasVerdict) {
      findings.push({ location: null, message: "description does not name an ALL-CAPS verdict token", excerpt: description });
    }
  }

  return findings;
}

function detectSectionOrder(skillText, config) {
  const expectedOrder = config["expected-order"] ?? [];
  const lines = skillText.split("\n");

  const positions = {};
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.trim() === "<HARD-GATE>" && !Object.hasOwn(positions, "<HARD-GATE>")) {
      positions["<HARD-GATE>"] = i;
    }
    const h2Match = line.match(/^## (.+)$/);
    if (h2Match) {
      const heading = h2Match[1].trim();
      if (expectedOrder.includes(heading) && !Object.hasOwn(positions, heading)) {
        positions[heading] = i;
      }
    }
  }

  const findings = [];
  let lastPos = -1;
  for (const section of expectedOrder) {
    if (!Object.hasOwn(positions, section)) {
      findings.push({ location: null, message: `section order violation: ${section} missing`, excerpt: null });
      continue;
    }
    if (positions[section] <= lastPos) {
      findings.push({ location: null, message: `section order violation: ${section} out of sequence`, excerpt: null });
    } else {
      lastPos = positions[section];
    }
  }

  return findings;
}

function detectCrossReference(skillText, config) {
  const leftSectionName = config["left-section"] ?? "";
  const rightSectionName = config["right-section"] ?? "";
  const leftPattern = new RegExp(config["left-pattern"] ?? "");
  const rightPattern = new RegExp(config["right-pattern"] ?? "");

  function extractSection(text, sectionSlug) {
    const normalized = sectionSlug.replace(/-/g, " ");
    const lines = text.split("\n");
    let inSection = false;
    const sectionLines = [];
    for (const line of lines) {
      const h2Match = line.match(/^## (.+)$/);
      if (h2Match) {
        if (inSection) break;
        if (h2Match[1].trim().toLowerCase() === normalized.toLowerCase()) {
          inSection = true;
          continue;
        }
      }
      if (inSection) sectionLines.push(line);
    }
    return sectionLines;
  }

  function extractLeadingNumber(line) {
    const m = line.match(/(\d+)/);
    return m ? parseInt(m[1], 10) : null;
  }

  const leftLines = extractSection(skillText, leftSectionName);
  const rightLines = extractSection(skillText, rightSectionName);

  const leftNumbers = leftLines.filter((l) => leftPattern.test(l)).map(extractLeadingNumber).filter((n) => n !== null);
  const rightNumbers = rightLines.filter((l) => rightPattern.test(l)).map(extractLeadingNumber).filter((n) => n !== null);

  const rightSet = new Set(rightNumbers);
  const leftSet = new Set(leftNumbers);

  const findings = [];
  for (const n of leftNumbers) {
    if (!rightSet.has(n)) {
      findings.push({ location: null, message: `cross-reference: checklist item ${n} has no matching step detail`, excerpt: null });
    }
  }
  for (const n of rightNumbers) {
    if (!leftSet.has(n)) {
      findings.push({ location: null, message: `cross-reference: step detail ${n} has no matching checklist item`, excerpt: null });
    }
  }

  return findings;
}

function detectHardGateSpan(skillText, config) {
  const findings = [];
  const maxSentences = config["max-sentences"] ?? 2;
  const forbidden = config["forbidden-tokens"] ?? [];
  const spanRe = /<HARD-GATE>([\s\S]*?)<\/HARD-GATE>/g;
  let match;
  while ((match = spanRe.exec(skillText)) !== null) {
    const content = match[1].trim();
    const sentences = content
      .split(/[.!?](?:\s+|$)/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    if (sentences.length > maxSentences) {
      findings.push({
        location: null,
        message: `HARD-GATE has ${sentences.length} sentences (max ${maxSentences})`,
        excerpt: content.slice(0, 120),
      });
    }
    for (const token of forbidden) {
      const re = new RegExp("\\b" + token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b", "i");
      if (re.test(content)) {
        findings.push({
          location: null,
          message: `HARD-GATE contains forbidden token: ${token}`,
          excerpt: content.slice(0, 120),
        });
      }
    }
  }
  return findings;
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
