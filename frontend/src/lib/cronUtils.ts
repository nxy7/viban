export function expandCronField(
  field: string,
  min: number,
  max: number,
): number[] {
  if (field === "*") {
    return Array.from({ length: max - min + 1 }, (_, i) => min + i);
  }

  const result: number[] = [];

  for (const part of field.split(",")) {
    if (part.includes("/")) {
      const [range, stepStr] = part.split("/");
      const step = parseInt(stepStr, 10);
      const [start, end] =
        range === "*"
          ? [min, max]
          : range.split("-").map((n) => parseInt(n, 10));

      for (let i = start; i <= (end ?? max); i += step) {
        if (i >= min && i <= max) result.push(i);
      }
    } else if (part.includes("-")) {
      const [start, end] = part.split("-").map((n) => parseInt(n, 10));
      for (let i = start; i <= end; i++) {
        if (i >= min && i <= max) result.push(i);
      }
    } else {
      const num = parseInt(part, 10);
      if (!Number.isNaN(num) && num >= min && num <= max) {
        result.push(num);
      }
    }
  }

  return [...new Set(result)].sort((a, b) => a - b);
}

export function matchesCronField(field: string, value: number): boolean {
  if (field === "*") return true;

  const values = expandCronField(field, 0, 59);
  return values.includes(value);
}

export function getNextRuns(
  expression: string,
  count: number = 3,
  fromDate?: Date,
): Date[] {
  if (!expression.trim()) return [];

  try {
    const parts = expression.trim().split(/\s+/);
    if (parts.length < 5) return [];

    const [minute, hour, dayOfMonth, month, dayOfWeek] = parts;
    const now = fromDate ?? new Date();
    const runs: Date[] = [];

    for (let i = 0; i < 365 && runs.length < count; i++) {
      const candidate = new Date(now.getTime() + i * 24 * 60 * 60 * 1000);

      if (!matchesCronField(month, candidate.getMonth() + 1)) continue;
      if (!matchesCronField(dayOfMonth, candidate.getDate())) continue;
      if (!matchesCronField(dayOfWeek, candidate.getDay())) continue;

      const hoursToCheck = expandCronField(hour, 0, 23);
      const minutesToCheck = expandCronField(minute, 0, 59);

      for (const h of hoursToCheck) {
        for (const m of minutesToCheck) {
          const runTime = new Date(candidate);
          runTime.setHours(h, m, 0, 0);

          if (runTime > now) {
            runs.push(runTime);
            if (runs.length >= count) break;
          }
        }
        if (runs.length >= count) break;
      }
    }

    return runs;
  } catch {
    return [];
  }
}

export function parseCronParts(
  value: string,
): [string, string, string, string, string] {
  const parts = value.trim().split(/\s+/);
  return [
    parts[0] || "0",
    parts[1] || "0",
    parts[2] || "*",
    parts[3] || "*",
    parts[4] || "6",
  ];
}
