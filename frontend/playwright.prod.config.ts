import { defineConfig, devices } from "@playwright/test";

/**
 * Playwright config for E2E tests against the production build.
 * The release should be started externally with:
 *   E2E_TEST=true PHX_SERVER=true DATABASE_URL=... SECRET_KEY_BASE=... \
 *   backend/_build/prod/rel/viban/bin/viban start
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
    baseURL: "http://localhost:8000",
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
