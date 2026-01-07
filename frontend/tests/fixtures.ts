import {
  type APIRequestContext,
  test as base,
  expect,
  type Page,
} from "@playwright/test";

interface TestFixtures {
  testApi: APIRequestContext;
  authenticatedPage: Page;
  boardName: string;
}

export const test = base.extend<TestFixtures>({
  testApi: async ({ playwright, baseURL }, use) => {
    const context = await playwright.request.newContext({
      baseURL: baseURL ?? "http://localhost:8000",
      ignoreHTTPSErrors: true,
      extraHTTPHeaders: {
        "Accept-Encoding": "identity",
      },
    });
    await use(context);
    await context.dispose();
  },

  authenticatedPage: async ({ page, testApi }, use) => {
    const loginResponse = await testApi.post("/api/test/login");
    expect(loginResponse.ok()).toBeTruthy();

    const loginData = await loginResponse.json();
    expect(loginData.ok).toBe(true);

    const cookies = await testApi.storageState();

    await page.context().addCookies(
      cookies.cookies.map((cookie) => ({
        ...cookie,
        domain: "localhost",
      })),
    );

    await use(page);
  },

  // biome-ignore lint/correctness/noEmptyPattern: Playwright fixture pattern
  boardName: async ({}, use) => {
    const name = `E2E Test ${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    await use(name);
  },
});

export { expect };

/**
 * Creates a board via API and navigates to it.
 * This bypasses the UI which requires repository selection.
 */
export async function createBoard(page: Page, name: string): Promise<string> {
  // Create board via test API
  const response = await page.request.post("/api/test/boards", {
    data: { name },
  });

  if (!response.ok()) {
    const text = await response.text();
    throw new Error(`Failed to create board: ${response.status()} ${text}`);
  }

  const data = await response.json();
  if (!data.ok) {
    throw new Error(`Failed to create board: ${data.error}`);
  }

  const boardId = data.board.id;

  // Navigate to the board
  await page.goto(`/board/${boardId}`);

  // Wait for board to load
  await expect(page.getByText("TODO")).toBeVisible({ timeout: 15000 });

  return boardId;
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
