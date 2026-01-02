import { request } from "@playwright/test";

const API_BASE = "http://localhost:7771";

async function globalTeardown() {
  console.log("Cleaning up E2E test data...");

  const context = await request.newContext({
    baseURL: API_BASE,
  });

  try {
    const response = await context.delete("/api/test/cleanup");
    if (response.ok()) {
      const data = await response.json();
      console.log(`Cleaned up ${data.deleted_boards} test boards`);
    } else {
      console.warn("Cleanup endpoint not available (sandbox not enabled?)");
    }
  } catch (error) {
    console.warn("Cleanup failed:", error);
  } finally {
    await context.dispose();
  }
}

export default globalTeardown;
