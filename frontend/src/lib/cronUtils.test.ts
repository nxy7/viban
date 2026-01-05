import { describe, expect, it } from "vitest";
import {
  expandCronField,
  getNextRuns,
  matchesCronField,
  parseCronParts,
} from "./cronUtils";

describe("expandCronField", () => {
  describe("wildcard (*)", () => {
    it("expands * to all values in range", () => {
      expect(expandCronField("*", 0, 5)).toEqual([0, 1, 2, 3, 4, 5]);
    });

    it("expands * for minutes (0-59)", () => {
      const result = expandCronField("*", 0, 59);
      expect(result).toHaveLength(60);
      expect(result[0]).toBe(0);
      expect(result[59]).toBe(59);
    });

    it("expands * for hours (0-23)", () => {
      const result = expandCronField("*", 0, 23);
      expect(result).toHaveLength(24);
      expect(result[0]).toBe(0);
      expect(result[23]).toBe(23);
    });
  });

  describe("single values", () => {
    it("parses single digit", () => {
      expect(expandCronField("5", 0, 59)).toEqual([5]);
    });

    it("parses double digit", () => {
      expect(expandCronField("30", 0, 59)).toEqual([30]);
    });

    it("ignores values outside range", () => {
      expect(expandCronField("60", 0, 59)).toEqual([]);
      expect(expandCronField("-1", 0, 59)).toEqual([]);
    });

    it("handles boundary values", () => {
      expect(expandCronField("0", 0, 59)).toEqual([0]);
      expect(expandCronField("59", 0, 59)).toEqual([59]);
    });
  });

  describe("comma-separated lists", () => {
    it("parses list of values", () => {
      expect(expandCronField("1,5,10", 0, 59)).toEqual([1, 5, 10]);
    });

    it("sorts and deduplicates values", () => {
      expect(expandCronField("10,5,1,5", 0, 59)).toEqual([1, 5, 10]);
    });

    it("filters out-of-range values", () => {
      expect(expandCronField("1,60,5", 0, 59)).toEqual([1, 5]);
    });

    it("handles days of week", () => {
      expect(expandCronField("0,6", 0, 6)).toEqual([0, 6]);
      expect(expandCronField("1,2,3,4,5", 0, 6)).toEqual([1, 2, 3, 4, 5]);
    });
  });

  describe("ranges (start-end)", () => {
    it("parses simple range", () => {
      expect(expandCronField("1-5", 0, 59)).toEqual([1, 2, 3, 4, 5]);
    });

    it("parses range starting at 0", () => {
      expect(expandCronField("0-3", 0, 59)).toEqual([0, 1, 2, 3]);
    });

    it("handles weekday range (Mon-Fri)", () => {
      expect(expandCronField("1-5", 0, 6)).toEqual([1, 2, 3, 4, 5]);
    });

    it("clips range to min/max bounds", () => {
      expect(expandCronField("55-65", 0, 59)).toEqual([55, 56, 57, 58, 59]);
    });
  });

  describe("step values (*/n or range/n)", () => {
    it("parses */5 for every 5th value", () => {
      expect(expandCronField("*/5", 0, 59)).toEqual([
        0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55,
      ]);
    });

    it("parses */15 for every 15th value", () => {
      expect(expandCronField("*/15", 0, 59)).toEqual([0, 15, 30, 45]);
    });

    it("parses */2 for even hours", () => {
      expect(expandCronField("*/2", 0, 23)).toEqual([
        0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22,
      ]);
    });

    it("parses range with step (9-17/2)", () => {
      expect(expandCronField("9-17/2", 0, 23)).toEqual([9, 11, 13, 15, 17]);
    });

    it("parses 0-30/10", () => {
      expect(expandCronField("0-30/10", 0, 59)).toEqual([0, 10, 20, 30]);
    });
  });

  describe("combined expressions", () => {
    it("parses combined list and range", () => {
      expect(expandCronField("1,5-7,10", 0, 59)).toEqual([1, 5, 6, 7, 10]);
    });

    it("parses multiple ranges", () => {
      expect(expandCronField("0-2,10-12", 0, 59)).toEqual([
        0, 1, 2, 10, 11, 12,
      ]);
    });

    it("handles complex month expression", () => {
      expect(expandCronField("1,3,6,9,12", 1, 12)).toEqual([1, 3, 6, 9, 12]);
    });
  });

  describe("edge cases", () => {
    it("handles empty string", () => {
      expect(expandCronField("", 0, 59)).toEqual([]);
    });

    it("handles invalid number", () => {
      expect(expandCronField("abc", 0, 59)).toEqual([]);
    });

    it("handles mixed valid/invalid", () => {
      expect(expandCronField("1,abc,5", 0, 59)).toEqual([1, 5]);
    });
  });
});

describe("matchesCronField", () => {
  it("matches wildcard for any value", () => {
    expect(matchesCronField("*", 0)).toBe(true);
    expect(matchesCronField("*", 30)).toBe(true);
    expect(matchesCronField("*", 59)).toBe(true);
  });

  it("matches exact value", () => {
    expect(matchesCronField("30", 30)).toBe(true);
    expect(matchesCronField("30", 31)).toBe(false);
  });

  it("matches value in list", () => {
    expect(matchesCronField("0,15,30,45", 15)).toBe(true);
    expect(matchesCronField("0,15,30,45", 16)).toBe(false);
  });

  it("matches value in range", () => {
    expect(matchesCronField("9-17", 12)).toBe(true);
    expect(matchesCronField("9-17", 8)).toBe(false);
    expect(matchesCronField("9-17", 18)).toBe(false);
  });

  it("matches step values", () => {
    expect(matchesCronField("*/15", 0)).toBe(true);
    expect(matchesCronField("*/15", 15)).toBe(true);
    expect(matchesCronField("*/15", 30)).toBe(true);
    expect(matchesCronField("*/15", 7)).toBe(false);
  });

  it("matches day of week (Sunday = 0)", () => {
    expect(matchesCronField("0", 0)).toBe(true);
    expect(matchesCronField("0,6", 0)).toBe(true);
    expect(matchesCronField("0,6", 6)).toBe(true);
    expect(matchesCronField("1-5", 3)).toBe(true);
    expect(matchesCronField("1-5", 0)).toBe(false);
  });
});

describe("parseCronParts", () => {
  it("parses standard 5-part cron expression", () => {
    expect(parseCronParts("0 9 * * 1-5")).toEqual(["0", "9", "*", "*", "1-5"]);
  });

  it("parses expression with all wildcards", () => {
    expect(parseCronParts("* * * * *")).toEqual(["*", "*", "*", "*", "*"]);
  });

  it("provides defaults for missing parts", () => {
    expect(parseCronParts("")).toEqual(["0", "0", "*", "*", "6"]);
    expect(parseCronParts("30")).toEqual(["30", "0", "*", "*", "6"]);
    expect(parseCronParts("30 9")).toEqual(["30", "9", "*", "*", "6"]);
  });

  it("handles extra whitespace", () => {
    expect(parseCronParts("  0   9   *   *   1  ")).toEqual([
      "0",
      "9",
      "*",
      "*",
      "1",
    ]);
  });

  it("parses common patterns", () => {
    expect(parseCronParts("0 0 * * 6")).toEqual(["0", "0", "*", "*", "6"]);
    expect(parseCronParts("0 */2 * * *")).toEqual(["0", "*/2", "*", "*", "*"]);
    expect(parseCronParts("0 9 1,15 * *")).toEqual([
      "0",
      "9",
      "1,15",
      "*",
      "*",
    ]);
  });
});

describe("getNextRuns", () => {
  const fixedDate = new Date("2024-06-15T10:30:00");

  it("returns empty array for empty expression", () => {
    expect(getNextRuns("", 3, fixedDate)).toEqual([]);
    expect(getNextRuns("   ", 3, fixedDate)).toEqual([]);
  });

  it("returns empty array for invalid expression", () => {
    expect(getNextRuns("invalid", 3, fixedDate)).toEqual([]);
    expect(getNextRuns("0 0", 3, fixedDate)).toEqual([]);
  });

  it("calculates next runs for daily at midnight", () => {
    const runs = getNextRuns("0 0 * * *", 3, fixedDate);
    expect(runs).toHaveLength(3);
    expect(runs[0].getHours()).toBe(0);
    expect(runs[0].getMinutes()).toBe(0);
    expect(runs[0] > fixedDate).toBe(true);
  });

  it("calculates next runs for specific hour", () => {
    const runs = getNextRuns("0 14 * * *", 3, fixedDate);
    expect(runs).toHaveLength(3);
    runs.forEach((run) => {
      expect(run.getHours()).toBe(14);
      expect(run.getMinutes()).toBe(0);
    });
  });

  it("calculates next run for Saturday at midnight", () => {
    const runs = getNextRuns("0 0 * * 6", 1, fixedDate);
    expect(runs).toHaveLength(1);
    expect(runs[0].getDay()).toBe(6);
    expect(runs[0].getHours()).toBe(0);
    expect(runs[0].getMinutes()).toBe(0);
  });

  it("calculates next runs for weekdays only", () => {
    const runs = getNextRuns("0 9 * * 1-5", 5, fixedDate);
    expect(runs).toHaveLength(5);
    runs.forEach((run) => {
      const day = run.getDay();
      expect(day >= 1 && day <= 5).toBe(true);
      expect(run.getHours()).toBe(9);
    });
  });

  it("calculates next runs for weekends", () => {
    const runs = getNextRuns("0 10 * * 0,6", 4, fixedDate);
    expect(runs).toHaveLength(4);
    runs.forEach((run) => {
      expect(run.getDay() === 0 || run.getDay() === 6).toBe(true);
    });
  });

  it("calculates next runs for specific day of month", () => {
    const runs = getNextRuns("0 9 15 * *", 3, fixedDate);
    expect(runs).toHaveLength(3);
    runs.forEach((run) => {
      expect(run.getDate()).toBe(15);
    });
  });

  it("calculates next runs for 1st and 15th", () => {
    const runs = getNextRuns("0 9 1,15 * *", 4, fixedDate);
    expect(runs).toHaveLength(4);
    runs.forEach((run) => {
      expect(run.getDate() === 1 || run.getDate() === 15).toBe(true);
    });
  });

  it("calculates next runs for specific month", () => {
    const runs = getNextRuns("0 0 1 12 *", 1, fixedDate);
    expect(runs).toHaveLength(1);
    expect(runs[0].getMonth()).toBe(11);
    expect(runs[0].getDate()).toBe(1);
  });

  it("calculates multiple runs for quarterly schedule", () => {
    const runs = getNextRuns("0 0 1 1,4,7,10 *", 4, fixedDate);
    expect(runs).toHaveLength(4);
    runs.forEach((run) => {
      expect([0, 3, 6, 9]).toContain(run.getMonth());
      expect(run.getDate()).toBe(1);
    });
  });

  it("calculates next runs for every 2 hours", () => {
    const runs = getNextRuns("0 */2 * * *", 5, fixedDate);
    expect(runs).toHaveLength(5);
    runs.forEach((run) => {
      expect(run.getHours() % 2).toBe(0);
    });
  });

  it("respects count parameter", () => {
    expect(getNextRuns("0 0 * * *", 1, fixedDate)).toHaveLength(1);
    expect(getNextRuns("0 0 * * *", 5, fixedDate)).toHaveLength(5);
    expect(getNextRuns("0 0 * * *", 10, fixedDate)).toHaveLength(10);
  });

  it("skips times in the past on current day", () => {
    const morning = new Date("2024-06-15T06:00:00");
    const runs = getNextRuns("0 9 * * *", 1, morning);
    expect(runs[0].getDate()).toBe(15);
    expect(runs[0].getHours()).toBe(9);

    const afternoon = new Date("2024-06-15T14:00:00");
    const runsAfternoon = getNextRuns("0 9 * * *", 1, afternoon);
    expect(runsAfternoon[0].getDate()).toBe(16);
  });

  it("returns runs in chronological order", () => {
    const runs = getNextRuns("0 0 * * *", 5, fixedDate);
    for (let i = 1; i < runs.length; i++) {
      expect(runs[i] > runs[i - 1]).toBe(true);
    }
  });

  it("handles multiple runs per day", () => {
    const runs = getNextRuns("0 9,12,18 * * *", 6, fixedDate);
    expect(runs).toHaveLength(6);

    const day1Runs = runs.filter(
      (r) => r.getDate() === runs[0].getDate(),
    ).length;
    expect(day1Runs).toBeGreaterThanOrEqual(1);
  });
});
