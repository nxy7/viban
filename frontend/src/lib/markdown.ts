/**
 * Shared markdown rendering utilities
 *
 * Centralizes markdown parsing configuration and rendering to avoid
 * duplicate marked.setOptions() calls and inconsistent parsing.
 */

import { marked } from "marked";

// Configure marked once with standard options
marked.setOptions({
  breaks: true,
  gfm: true,
});

/**
 * Safely parses markdown content to HTML string
 * Returns the original content if parsing fails
 */
export function renderMarkdown(content: string): string {
  try {
    return marked.parse(content) as string;
  } catch {
    return content;
  }
}

/**
 * CSS classes for prose styling in task cards (compact)
 */
export const TASK_CARD_PROSE_CLASSES = `
  prose prose-invert prose-xs max-w-none
  prose-headings:text-gray-300 prose-headings:font-semibold prose-headings:mt-1 prose-headings:mb-0.5
  prose-h1:text-xs prose-h2:text-xs prose-h3:text-xs
  prose-p:my-0.5 prose-ul:my-0.5 prose-li:my-0 prose-ol:my-0.5
  prose-code:text-brand-300 prose-code:bg-gray-900/50 prose-code:px-1 prose-code:rounded
`.trim();

/**
 * CSS classes for prose styling in task details (standard)
 */
export const TASK_DETAILS_PROSE_CLASSES = `
  prose prose-sm prose-invert max-w-none
  prose-p:my-1 prose-ul:my-1 prose-li:my-0 prose-headings:my-2 prose-headings:text-gray-200
`.trim();

/**
 * CSS classes for prose styling in chat/output bubbles
 */
export const CHAT_PROSE_CLASSES = `
  prose prose-sm prose-invert max-w-none
  prose-pre:bg-gray-900 prose-pre:text-gray-200
  prose-code:text-brand-300 prose-code:bg-gray-900/50 prose-code:px-1 prose-code:py-0.5 prose-code:rounded
`.trim();
