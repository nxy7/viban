import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : undefined,
  reporter: "html",
  use: {
    baseURL: "https://localhost:7777",
    ignoreHTTPSErrors: true,
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "firefox",
      use: { ...devices["Desktop Firefox"] },
    },
  ],
  // Global setup/teardown for test cleanup
  globalTeardown: "./tests/global-teardown.ts",
  webServer: [
    {
      // Caddy handles HTTPS and proxies to Phoenix
      command: "caddy run --config ../Caddyfile",
      url: "https://localhost:7777/api/health",
      ignoreHTTPSErrors: true,
      reuseExistingServer: !process.env.CI,
      timeout: 120 * 1000,
    },
    {
      // E2E_TEST=true enables /api/test/* endpoints
      command: "cd ../backend && E2E_TEST=true mix phx.server",
      url: "http://localhost:7780/api/health",
      reuseExistingServer: !process.env.CI,
      timeout: 120 * 1000,
    },
    {
      command: "bun dev",
      url: "http://localhost:7778",
      reuseExistingServer: !process.env.CI,
      timeout: 120 * 1000,
    },
  ],
});
