#!/usr/bin/env node
// Normalize a DigitalExperienceBundle so a re-pull after a staff edit in
// Experience Builder produces a reviewable diff instead of churn.
//
// Experience Builder rewrites the bundle's JSON on every publish (key ordering
// in particular is not stable). This pass gives us a deterministic canonical
// form: object keys sorted recursively, arrays left in place (their order is
// semantic — component composition on a page). It is intentionally idempotent:
//   normalize(normalize(x)) === normalize(x)
// which is the property the round-trip contract test asserts (plan §7.4).
//
// Serialization is delegated to prettier using the repo's own config, so the
// normalizer's output is byte-identical to what lint-staged writes on commit —
// the two never fight (e.g. over short-array wrapping). We deliberately do NOT
// strip fields yet — over-stripping risks breaking a deploy. Volatile-field
// stripping is tuned later against a real staff-edit re-pull (plan §7.1, §11).
//
// Usage:
//   node scripts/normalize-experience-bundle.mjs [bundleDir|file ...]
// Defaults to every bundle under force-app/main/default/digitalExperiences.

import { readFileSync, writeFileSync, globSync } from "node:fs";
import { argv, exit } from "node:process";
import prettier from "prettier";

const DEFAULT_GLOB = "force-app/main/default/digitalExperiences/**/*.json";

// Pure, exported for the determinism contract test (plan §7.4).
export function sortKeysDeep(value) {
  if (Array.isArray(value)) {
    // Preserve array order — it carries meaning (page component order, etc.).
    return value.map(sortKeysDeep);
  }
  if (value && typeof value === "object") {
    const out = {};
    for (const key of Object.keys(value).sort()) {
      out[key] = sortKeysDeep(value[key]);
    }
    return out;
  }
  return value;
}

function targets() {
  const args = argv.slice(2);
  if (args.length === 0) return globSync(DEFAULT_GLOB);
  return args.flatMap((p) =>
    p.endsWith(".json") ? [p] : globSync(`${p}/**/*.json`)
  );
}

async function main() {
  let changed = 0;
  let scanned = 0;
  for (const file of targets()) {
    scanned += 1;
    const raw = readFileSync(file, "utf8");
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (err) {
      console.error(`✗ ${file}: invalid JSON — ${err.message}`);
      exit(1);
    }
    const config = (await prettier.resolveConfig(file)) ?? {};
    const next = await prettier.format(JSON.stringify(sortKeysDeep(parsed)), {
      ...config,
      parser: "json",
    });
    if (next !== raw) {
      writeFileSync(file, next);
      changed += 1;
    }
  }
  console.log(
    `✓ normalized ${scanned} JSON file(s) in the bundle (${changed} rewritten)`
  );
}

// Run only when invoked directly, so importing the module (tests) has no
// side effects.
if (import.meta.url === `file://${argv[1]}`) {
  await main();
}
