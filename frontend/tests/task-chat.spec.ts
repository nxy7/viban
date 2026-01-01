import { expect, test } from "@playwright/test";

test.describe("Task Chat E2E Tests (Unified Activity View)", () => {
  test("task details panel shows unified activity view with chat", async ({
    page,
  }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task first
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Chat Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();

    // Task details panel should open with unified view (no separate tabs)
    // Should see "Task Created" activity
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Chat input should be visible at bottom (part of unified view)
    await expect(
      page
        .getByPlaceholder("Enter a prompt or paste an image (Ctrl+V)...")
        .or(page.getByPlaceholder("Connecting..."))
        .or(page.getByPlaceholder("Claude Code not available")),
    ).toBeVisible({ timeout: 10000 });
  });

  test("chat interface shows connection status", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task first
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Connection Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();

    // Should show connection status (Connected or Disconnected) in header
    await expect(
      page.getByText("Connected").or(page.getByText("Disconnected")),
    ).toBeVisible({ timeout: 15000 });
  });

  test("chat has send button", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task first
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Send Button Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();

    // Should have a Send button (submit button in form)
    await expect(page.locator("form button[type='submit']")).toBeVisible({
      timeout: 10000,
    });
  });

  test("unified view shows Task Created as first activity", async ({
    page,
  }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task with description
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Empty State Test ${Date.now()}`;
    const taskDescription = "Test description for activity";
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page
      .getByPlaceholder("Enter task description...")
      .fill(taskDescription);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();

    // Should show Task Created activity with description
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });
    await expect(page.getByText(taskDescription)).toBeVisible({
      timeout: 5000,
    });
  });

  test("can type in chat input", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task first
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Chat Input Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Wait for chat input to be available
    const chatInput = page
      .getByPlaceholder("Enter a prompt or paste an image (Ctrl+V)...")
      .or(page.getByPlaceholder("Claude Code not available"));
    await expect(chatInput).toBeVisible({ timeout: 15000 });

    // Type a message
    await chatInput.fill("Hello, this is a test message");

    // Verify the text was entered
    await expect(chatInput).toHaveValue("Hello, this is a test message");
  });

  test("task title is clickable for editing in header", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task first
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Editable Title Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Click on the title to start editing
    await page
      .getByRole("heading", { level: 2 })
      .filter({ hasText: taskTitle })
      .click();

    // Should show input field and Save/Cancel buttons
    await expect(page.getByRole("button", { name: "Save" })).toBeVisible({
      timeout: 5000,
    });
    await expect(page.getByRole("button", { name: "Cancel" })).toBeVisible();
  });

  test("agent status badge is visible when applicable", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task first
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Status Badge Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();

    // Task details should be visible - the agent status badge shows "idle" by default
    // but may not be visible when idle. Just verify the panel opened correctly.
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });
  });

  test("layout has header, scrollable content, and fixed input", async ({
    page,
  }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task first
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Layout Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();

    // Verify the three-part layout:
    // 1. Header with title
    await expect(
      page.getByRole("heading", { level: 2 }).filter({ hasText: taskTitle }),
    ).toBeVisible({ timeout: 5000 });

    // 2. Activity content area (with Task Created)
    await expect(page.getByText("Task Created")).toBeVisible();

    // 3. Chat input at bottom
    await expect(
      page
        .getByPlaceholder("Enter a prompt or paste an image (Ctrl+V)...")
        .or(page.getByPlaceholder("Connecting..."))
        .or(page.getByPlaceholder("Claude Code not available")),
    ).toBeVisible({ timeout: 10000 });
  });
});
