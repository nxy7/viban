import { describe, expect, it } from "vitest";
import {
  FUZZY_TOLERANCE,
  fuzzyMatch,
  fuzzyWordMatch,
  levenshteinDistance,
} from "./fuzzySearch";

describe("levenshteinDistance", () => {
  it("returns 0 for identical strings", () => {
    expect(levenshteinDistance("test", "test")).toBe(0);
  });

  it("returns length of other string when one is empty", () => {
    expect(levenshteinDistance("", "test")).toBe(4);
    expect(levenshteinDistance("test", "")).toBe(4);
  });

  it("counts single character substitution", () => {
    expect(levenshteinDistance("test", "tast")).toBe(1);
  });

  it("counts single character insertion", () => {
    expect(levenshteinDistance("test", "tests")).toBe(1);
  });

  it("counts single character deletion", () => {
    expect(levenshteinDistance("tests", "test")).toBe(1);
  });

  it("handles multiple edits", () => {
    expect(levenshteinDistance("kitten", "sitting")).toBe(3);
  });
});

describe("fuzzyWordMatch", () => {
  it("matches exact substring", () => {
    expect(fuzzyWordMatch("Authentication", "auth")).toBe(true);
  });

  it("matches case-insensitively", () => {
    expect(fuzzyWordMatch("HELLO", "hello")).toBe(true);
  });

  it("tolerates typos within threshold", () => {
    expect(fuzzyWordMatch("authentication", "authentcation")).toBe(true);
  });

  it("rejects strings beyond tolerance", () => {
    expect(fuzzyWordMatch("cat", "dog")).toBe(false);
  });

  it("matches word boundaries", () => {
    expect(fuzzyWordMatch("user authentication system", "user")).toBe(true);
    expect(fuzzyWordMatch("user authentication system", "system")).toBe(true);
  });
});

describe("fuzzyMatch", () => {
  it("returns true for empty query", () => {
    expect(fuzzyMatch("any text", "")).toBe(true);
  });

  it("matches all query words", () => {
    expect(fuzzyMatch("User Authentication System", "user auth")).toBe(true);
  });

  it("fails if any word does not match", () => {
    expect(fuzzyMatch("User Authentication", "user database")).toBe(false);
  });

  it("handles multiple spaces in query", () => {
    expect(fuzzyMatch("User Authentication", "user   auth")).toBe(true);
  });

  it("matches with typos", () => {
    expect(fuzzyMatch("Authentication", "authentcation")).toBe(true);
  });
});

describe("FUZZY_TOLERANCE", () => {
  it("is set to 15%", () => {
    expect(FUZZY_TOLERANCE).toBe(0.15);
  });
});
