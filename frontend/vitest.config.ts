import solid from "vite-plugin-solid";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [solid()],
  test: {
    // Use node environment to avoid jsdom dependency prompt
    environment: "node",
    // Exclude Playwright E2E tests - they should be run with `bun run test:e2e`
    exclude: [
      "**/node_modules/**",
      "**/dist/**",
      "**/tests/**", // Playwright tests live here
      "**/*.spec.ts",
      "**/*.spec.tsx",
    ],
    // Include only unit tests (*.test.ts files in src/)
    include: ["src/**/*.test.{ts,tsx}"],
    // passWithNoTests since we currently only have E2E tests
    passWithNoTests: true,
  },
});
