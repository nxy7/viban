import {
  type APIRequestContext,
  test as base,
  expect,
  type Page,
} from "@playwright/test";

const API_BASE = "http://localhost:7771";

interface TestFixtures {
  testApi: APIRequestContext;
  authenticatedPage: Page;
  boardName: string;
}

export const test = base.extend<TestFixtures>({
  testApi: async ({ playwright }, use) => {
    const context = await playwright.request.newContext({
      baseURL: API_BASE,
    });
    await use(context);
    await context.dispose();
  },

  authenticatedPage: async ({ page, testApi }, use) => {
    // Login as test user
    const loginResponse = await testApi.post("/api/test/login");
    expect(loginResponse.ok()).toBeTruthy();

    const loginData = await loginResponse.json();
    expect(loginData.ok).toBe(true);

    // Get cookies from the API response and set them on the page
    const cookies = await testApi.storageState();

    // Set the cookies on the browser context
    await page.context().addCookies(
      cookies.cookies.map((cookie) => ({
        ...cookie,
        // Ensure cookies work for the frontend
        domain: "localhost",
      })),
    );

    await use(page);
  },

  // biome-ignore lint/correctness/noEmptyPattern: Playwright fixture pattern
  boardName: async ({}, use) => {
    // Generate unique board name for this test
    const name = `E2E Test ${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    await use(name);
  },
});

export { expect };

/**
 * Creates a board via the UI and returns the board ID from the URL
 */
export async function createBoard(page: Page, name: string): Promise<string> {
  await page.goto("/");

  // Click "New Board" button
  await page.getByRole("button", { name: /new.*board/i }).click();

  // Fill in board name
  await page.getByPlaceholder(/board name/i).fill(name);

  // Submit
  await page.getByRole("button", { name: /create/i }).click();

  // Wait for navigation to board page
  await page.waitForURL(/\/board\/.+/);

  // Extract board ID from URL
  const url = page.url();
  const match = url.match(/\/board\/([^/?]+)/);
  if (!match) {
    throw new Error(`Could not extract board ID from URL: ${url}`);
  }

  return match[1];
}

/**
 * Creates a task via the UI
 */
export async function createTask(
  page: Page,
  title: string,
  description?: string,
): Promise<void> {
  // Click "Add a card" button in first column
  const addCardButton = page
    .getByRole("button", { name: /add a card/i })
    .first();
  await expect(addCardButton).toBeVisible({ timeout: 15000 });
  await addCardButton.click();

  // Fill in task details
  await page.getByPlaceholder("Enter task title...").fill(title);
  if (description) {
    await page.getByPlaceholder("Enter task description...").fill(description);
  }

  // Submit
  await page.getByRole("button", { name: "Create Task" }).click();

  // Wait for modal to close
  await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
    timeout: 5000,
  });

  // Wait for task to appear
  await expect(page.getByText(title)).toBeVisible({ timeout: 15000 });
}

/**
 * Navigates to a board by clicking on it from the home page
 */
export async function navigateToBoard(
  page: Page,
  boardName: string,
): Promise<void> {
  await page.goto("/");

  // Find and click the board link
  const boardLink = page.getByRole("link", { name: boardName });
  await expect(boardLink).toBeVisible({ timeout: 15000 });
  await boardLink.click();

  // Wait for board page to load
  await page.waitForURL(/\/board\/.+/);
  await expect(page.getByText("TODO")).toBeVisible({ timeout: 15000 });
}

/**
 * Cleanup helper to delete test boards after tests
 */
export async function cleanupTestBoards(
  testApi: APIRequestContext,
): Promise<number> {
  const response = await testApi.delete("/api/test/cleanup");
  if (!response.ok()) {
    console.warn("Cleanup failed:", await response.text());
    return 0;
  }
  const data = await response.json();
  return data.deleted_boards || 0;
}
