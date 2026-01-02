/**
 * Extract a human-readable error message from an unknown error value.
 * Handles Error instances, strings, and falls back to a default message.
 */
export function getErrorMessage(
  error: unknown,
  fallback: string = "An unexpected error occurred",
): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === "string") {
    return error;
  }
  return fallback;
}
