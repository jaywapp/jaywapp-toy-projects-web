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

test("invalid and empty period keys are rejected", () => {
  for (const key of ["", "2026-00", "2026-13", "2026-2", "2026-02-01", " 2026-02", "2026-02\n"]) {
    assert.equal(isValidPeriodKey(key), false, key);
    assert.throws(() => getPeriodRange(key), /Invalid periodKey/);
  }
});

test("December rolls into the next year and leap February includes 29 days", () => {
  const december = getPeriodRange("2026-12");
  assert.equal(december.end.getFullYear(), 2027);
  assert.equal(december.end.getMonth(), 0);
  const february = getPeriodRange("2024-02");
  const lastDay = new Date(february.end.getTime());
  lastDay.setDate(lastDay.getDate() - 1);
  assert.equal(lastDay.getDate(), 29);
  assert.equal(lastDay.getMonth(), 1);
});
