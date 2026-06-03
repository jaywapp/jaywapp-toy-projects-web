import assert from "node:assert/strict";
import test from "node:test";

import {getPeriodRange, isValidPeriodKey} from "./period";

test("isValidPeriodKey validates YYYY-MM format", () => {
  assert.equal(isValidPeriodKey("2026-02"), true);
  assert.equal(isValidPeriodKey("2026-13"), false);
  assert.equal(isValidPeriodKey("26-02"), false);
});

test("getPeriodRange returns month boundary dates", () => {
  const range = getPeriodRange("2026-02");
  assert.equal(range.start.getFullYear(), 2026);
  assert.equal(range.start.getMonth(), 1);
  assert.equal(range.start.getDate(), 1);
  assert.equal(range.end.getFullYear(), 2026);
  assert.equal(range.end.getMonth(), 2);
  assert.equal(range.end.getDate(), 1);
});
