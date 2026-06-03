"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isValidPeriodKey = isValidPeriodKey;
exports.getPeriodRange = getPeriodRange;
const PERIOD_KEY_REGEX = /^(\d{4})-(0[1-9]|1[0-2])$/;
function isValidPeriodKey(periodKey) {
    return PERIOD_KEY_REGEX.test(periodKey);
}
function getPeriodRange(periodKey) {
    const match = PERIOD_KEY_REGEX.exec(periodKey);
    if (!match) {
        throw new Error(`Invalid periodKey: ${periodKey}`);
    }
    const year = Number(match[1]);
    const month = Number(match[2]);
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 1);
    return { start, end };
}
//# sourceMappingURL=period.js.map