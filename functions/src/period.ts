const PERIOD_KEY_REGEX = /^(\d{4})-(0[1-9]|1[0-2])$/;

export function isValidPeriodKey(periodKey: string): boolean {
  return PERIOD_KEY_REGEX.test(periodKey);
}

export function getPeriodRange(periodKey: string): {start: Date; end: Date} {
  const match = PERIOD_KEY_REGEX.exec(periodKey);
  if (!match) {
    throw new Error(`Invalid periodKey: ${periodKey}`);
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 1);
  return {start, end};
}
