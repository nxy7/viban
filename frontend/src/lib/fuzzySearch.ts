export const FUZZY_TOLERANCE = 0.15;

export function levenshteinDistance(a: string, b: string): number {
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;

  const matrix: number[][] = [];

  for (let i = 0; i <= b.length; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= a.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      if (b[i - 1] === a[j - 1]) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1,
        );
      }
    }
  }

  return matrix[b.length][a.length];
}

export function fuzzyWordMatch(text: string, queryWord: string): boolean {
  const lowerText = text.toLowerCase();
  const lowerWord = queryWord.toLowerCase();
  const maxDistance = Math.max(1, Math.floor(lowerWord.length * FUZZY_TOLERANCE));

  if (lowerText.includes(lowerWord)) return true;

  const textWords = lowerText.split(/\s+/);
  for (const textWord of textWords) {
    if (Math.abs(textWord.length - lowerWord.length) > maxDistance) continue;
    if (levenshteinDistance(textWord, lowerWord) <= maxDistance) return true;
  }

  if (lowerWord.length >= 3) {
    for (let i = 0; i <= lowerText.length - lowerWord.length; i++) {
      const substring = lowerText.slice(i, i + lowerWord.length);
      if (levenshteinDistance(substring, lowerWord) <= maxDistance) return true;
    }
  }

  return false;
}

export function fuzzyMatch(text: string, query: string): boolean {
  if (!query) return true;

  const queryWords = query
    .toLowerCase()
    .split(/\s+/)
    .filter((w) => w.length > 0);

  return queryWords.every((word) => fuzzyWordMatch(text, word));
}
