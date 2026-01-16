function isSSR(): boolean {
  return typeof window === "undefined";
}

export function getStoredBoolean(key: string, defaultValue: boolean): boolean {
  if (isSSR()) return defaultValue;
  try {
    const stored = localStorage.getItem(key);
    if (stored === null) return defaultValue;
    return stored === "true";
  } catch {
    return defaultValue;
  }
}

export function setStoredBoolean(key: string, value: boolean): void {
  if (isSSR()) return;
  try {
    localStorage.setItem(key, String(value));
  } catch {
    // Storage quota exceeded or private browsing
  }
}

export function getStoredString(key: string): string | null {
  if (isSSR()) return null;
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function setStoredString(key: string, value: string): void {
  if (isSSR()) return;
  try {
    localStorage.setItem(key, value);
  } catch {
    // Storage quota exceeded or private browsing
  }
}

export function removeStoredItem(key: string): void {
  if (isSSR()) return;
  try {
    localStorage.removeItem(key);
  } catch {
    // Storage not available
  }
}
