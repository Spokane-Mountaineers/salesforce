// Contract test for the bundle normalizer (plan §7.4, "deployment round-trip").
// Run: node --test scripts/
//
// Asserts the canonical form is deterministic and idempotent, so the pull→push
// loop can't silently reorder the bundle: sortKeysDeep(sortKeysDeep(x)) is
// structurally equal to sortKeysDeep(x), key order is stable regardless of input
// order, and array order is preserved (it carries page-composition meaning).

import { test } from "node:test";
import assert from "node:assert/strict";
import { sortKeysDeep } from "./normalize-experience-bundle.mjs";

test("sorts object keys regardless of input order", () => {
  const a = sortKeysDeep({ b: 1, a: 2, c: 3 });
  const b = sortKeysDeep({ c: 3, a: 2, b: 1 });
  assert.deepEqual(Object.keys(a), ["a", "b", "c"]);
  assert.equal(JSON.stringify(a), JSON.stringify(b));
});

test("is idempotent: normalize(normalize(x)) === normalize(x)", () => {
  const input = {
    z: { y: [{ q: 1, p: 2 }], x: "v" },
    a: [3, 1, 2],
    m: { c: 1, a: 2, b: 3 },
  };
  const once = JSON.stringify(sortKeysDeep(input));
  const twice = JSON.stringify(sortKeysDeep(JSON.parse(once)));
  assert.equal(twice, once);
});

test("preserves array order (semantic component ordering)", () => {
  const out = sortKeysDeep({ items: [{ b: 1 }, { a: 2 }, { c: 3 }] });
  // Array element order unchanged; only keys within each element sorted.
  assert.deepEqual(out.items, [{ b: 1 }, { a: 2 }, { c: 3 }]);
});

test("sorts keys nested inside arrays", () => {
  const out = sortKeysDeep({ items: [{ b: 1, a: 2 }] });
  assert.deepEqual(Object.keys(out.items[0]), ["a", "b"]);
});

test("passes through primitives and null", () => {
  assert.equal(sortKeysDeep("s"), "s");
  assert.equal(sortKeysDeep(7), 7);
  assert.equal(sortKeysDeep(null), null);
  assert.equal(sortKeysDeep(true), true);
});
