import { defineConfig, devices } from "@playwright/test";

/**
 * Playwright config for E2E tests against the production build.
 * The release runs in deploy mode (auto-starts Postgres Docker) with:
 *   E2E_TEST=true backend/_build/prod/rel/viban/bin/viban start
 */
export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    // Production release serves frontend from the backend on same port
    // Deploy mode default port is 7777, HTTPS with self-signed certs
    baseURL: "https://localhost:7777",
    ignoreHTTPSErrors: true,
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  globalTeardown: "./tests/global-teardown.ts",
  // No webServer config - release is started externally by CI
});
