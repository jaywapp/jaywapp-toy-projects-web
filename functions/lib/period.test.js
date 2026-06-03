"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const period_1 = require("./period");
(0, node_test_1.default)("isValidPeriodKey validates YYYY-MM format", () => {
    strict_1.default.equal((0, period_1.isValidPeriodKey)("2026-02"), true);
    strict_1.default.equal((0, period_1.isValidPeriodKey)("2026-13"), false);
    strict_1.default.equal((0, period_1.isValidPeriodKey)("26-02"), false);
});
(0, node_test_1.default)("getPeriodRange returns month boundary dates", () => {
    const range = (0, period_1.getPeriodRange)("2026-02");
    strict_1.default.equal(range.start.getFullYear(), 2026);
    strict_1.default.equal(range.start.getMonth(), 1);
    strict_1.default.equal(range.start.getDate(), 1);
    strict_1.default.equal(range.end.getFullYear(), 2026);
    strict_1.default.equal(range.end.getMonth(), 2);
    strict_1.default.equal(range.end.getDate(), 1);
});
//# sourceMappingURL=period.test.js.map