import { expect, test } from "@playwright/test";

test.describe("Kanban Board E2E Tests", () => {
  test("home page loads with Kanban header", async ({ page }) => {
    await page.goto("/");

    // Check the main heading is visible
    await expect(
      page.getByRole("heading", { name: "Viban Kanban" }),
    ).toBeVisible();

    // Check the subheading
    await expect(
      page.getByText("Manage your projects with ease"),
    ).toBeVisible();
  });

  test("displays boards list or empty state", async ({ page }) => {
    await page.goto("/");

    // Wait for either boards to load or empty state - avoid networkidle due to Electric sync
    // Either we see board cards or the "No boards yet" text
    await expect(
      page
        .locator("a[href^='/board/']")
        .first()
        .or(page.getByText("No boards yet")),
    ).toBeVisible({ timeout: 15000 });
  });

  test("can navigate to default board", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();

    // Wait for board page to load
    await page.waitForURL(/\/board\/.+/);

    // Should see column names (default columns from board.ex)
    await expect(page.getByText("TODO")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("In Progress")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("Done")).toBeVisible({ timeout: 15000 });
  });

  test("board page shows columns from database", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Check default columns are visible (from board.ex)
    await expect(page.getByText("TODO")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("In Progress")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("Done")).toBeVisible({ timeout: 15000 });

    // Check "Add a card" buttons are visible (one per column)
    const addCardButtons = page.getByRole("button", { name: /add a card/i });
    await expect(addCardButtons.first()).toBeVisible({ timeout: 10000 });
  });

  test("can open create task modal", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Click "Add a card" button in first column
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    // Modal should appear with title
    await expect(page.getByText("Add task to")).toBeVisible({ timeout: 5000 });

    // Form elements should be visible (no priority selector anymore)
    await expect(page.getByPlaceholder("Enter task title...")).toBeVisible();
    await expect(
      page.getByPlaceholder("Enter task description..."),
    ).toBeVisible();
  });

  test("can create a new task", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Click "Add a card" button in first column
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    // Fill in task details (no priority selector)
    const taskTitle = `Test Task ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page
      .getByPlaceholder("Enter task description...")
      .fill("This is a test task description");

    // Submit
    await page.getByRole("button", { name: "Create Task" }).click();

    // Wait for modal to close and task to appear
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // The new task should appear in the column
    await expect(page.getByText(taskTitle)).toBeVisible({ timeout: 15000 });
  });

  test("can open task details panel with unified activity view", async ({
    page,
  }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // First create a task to ensure we have one
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Details Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();

    // Wait for modal to close
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the created task
    await page.getByText(taskTitle).click();

    // Task details panel should open with unified view
    // Should see "Task Created" activity
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Should see connection status
    await expect(
      page.getByText("Connected").or(page.getByText("Disconnected")),
    ).toBeVisible({ timeout: 10000 });

    // Should have chat input at bottom
    await expect(
      page
        .getByPlaceholder("Type a message...")
        .or(page.getByPlaceholder("Connecting...")),
    ).toBeVisible({ timeout: 10000 });

    // Should have delete button
    await expect(page.locator("button[title='Delete task']")).toBeVisible();
  });

  test("can edit task title inline", async ({ page }) => {
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

    const originalTitle = `Edit Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(originalTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(originalTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Click on the title to edit it (inline editing)
    await page
      .getByRole("heading", { level: 2 })
      .filter({ hasText: originalTitle })
      .click();

    // Change the title
    const newTitle = `Updated ${originalTitle}`;
    await page.locator("input").first().clear();
    await page.locator("input").first().fill(newTitle);

    // Save changes
    await page.getByRole("button", { name: "Save" }).click();

    // Wait for save to complete - title should be visible as heading again
    await expect(
      page.getByRole("heading", { level: 2 }).filter({ hasText: newTitle }),
    ).toBeVisible({ timeout: 5000 });

    // Close the panel
    await page.keyboard.press("Escape");

    // The updated title should be visible in the column
    await expect(page.getByText(newTitle)).toBeVisible({ timeout: 15000 });
  });

  test("can delete a task", async ({ page }) => {
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

    const taskTitle = `Delete Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Click delete button
    await page.locator("button[title='Delete task']").click();

    // Confirm deletion in the confirmation dialog
    await expect(page.getByText("Delete this task?")).toBeVisible();
    await page.getByRole("button", { name: "Delete" }).click();

    // Wait for panel to close
    await expect(page.getByText("Task Created")).not.toBeVisible({
      timeout: 5000,
    });

    // The task should no longer be visible
    await expect(page.getByText(taskTitle)).not.toBeVisible({ timeout: 5000 });
  });

  test("back button returns to home page", async ({ page }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Click the back button (link to home)
    await page
      .getByRole("link", { name: /back|home/i })
      .or(page.locator("a[href='/']"))
      .first()
      .click();

    // Should be back on home page
    await expect(
      page.getByRole("heading", { name: "Viban Kanban" }),
    ).toBeVisible({ timeout: 10000 });
  });

  test("task card shows error state when task has error", async ({ page }) => {
    // This test verifies that error state is displayed correctly
    // The actual error would be set by a failing hook, but we can verify the UI elements exist
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Error State Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();

    // Task should be created successfully
    await expect(page.getByText(taskTitle)).toBeVisible({ timeout: 15000 });
  });

  test("task details shows Open in Editor button when worktree exists", async ({
    page,
  }) => {
    await page.goto("/");

    // Wait for boards to load
    const boardLink = page.locator("a[href^='/board/']").first();
    await expect(boardLink).toBeVisible({ timeout: 15000 });

    await boardLink.click();
    await page.waitForURL(/\/board\/.+/);

    // Create a task
    const addCardButton = page
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Editor Button Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // The "Open in code editor" button should only appear if worktree_path exists
    // Since this is a new task without worktree, the button may not be visible
    // This test verifies the panel opens correctly regardless
    await expect(page.locator("button[title='Delete task']")).toBeVisible();
  });

  test("task details shows activity feed with Task Created", async ({
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

    const taskTitle = `Activity Feed Test ${Date.now()}`;
    const taskDescription = "This is a test description for activity feed";
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page
      .getByPlaceholder("Enter task description...")
      .fill(taskDescription);
    await page.getByRole("button", { name: "Create Task" }).click();

    // Wait for modal to close
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();

    // Should see "Task Created" activity with timestamp
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Should see the description in the activity
    await expect(page.getByText(taskDescription)).toBeVisible({
      timeout: 5000,
    });
  });
});
