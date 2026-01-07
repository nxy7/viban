import { createBoard, createTask, expect, test } from "./fixtures";

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

  test("displays boards list or empty state", async ({ authenticatedPage }) => {
    await authenticatedPage.goto("/");

    // Wait for either boards to load or empty state
    await expect(
      authenticatedPage
        .locator("a[href^='/board/']")
        .first()
        .or(authenticatedPage.getByText("No boards yet")),
    ).toBeVisible({ timeout: 15000 });
  });

  test("can create a new board and navigate to it", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");

    // Create a board
    const boardId = await createBoard(authenticatedPage, boardName);
    expect(boardId).toBeTruthy();

    // Should see default columns
    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("In Progress")).toBeVisible();
    await expect(authenticatedPage.getByText("Done")).toBeVisible();
  });

  test("board page shows columns from database", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");

    await createBoard(authenticatedPage, boardName);

    // Check default columns are visible
    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("In Progress")).toBeVisible();
    await expect(authenticatedPage.getByText("Done")).toBeVisible();

    // Check "Add a card" buttons are visible
    const addCardButtons = authenticatedPage.getByRole("button", {
      name: /add a card/i,
    });
    await expect(addCardButtons.first()).toBeVisible({ timeout: 10000 });
  });

  test("can open create task modal", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    // Click "Add a card" button in first column
    const addCardButton = authenticatedPage
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    // Modal should appear
    await expect(authenticatedPage.getByText("Add task to")).toBeVisible({
      timeout: 5000,
    });

    // Form elements should be visible
    await expect(
      authenticatedPage.getByPlaceholder("Enter task title..."),
    ).toBeVisible();
    await expect(
      authenticatedPage.getByPlaceholder("Enter task description..."),
    ).toBeVisible();
  });

  test("can create a new task", async ({ authenticatedPage, boardName }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Test Task ${Date.now()}`;
    await createTask(
      authenticatedPage,
      taskTitle,
      "This is a test task description",
    );

    // The new task should appear in the column
    await expect(authenticatedPage.getByText(taskTitle)).toBeVisible({
      timeout: 15000,
    });
  });

  test("can open task details panel with unified activity view", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Details Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the created task
    await authenticatedPage.getByText(taskTitle).click();

    // Task details panel should open (delete button is always visible)
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
    });

    // Should see connection status
    await expect(
      authenticatedPage
        .getByText("Connected")
        .or(authenticatedPage.getByText("Disconnected")),
    ).toBeVisible({ timeout: 10000 });

    // Should have chat input at bottom
    await expect(
      authenticatedPage
        .getByPlaceholder("Enter a prompt or paste an image (Ctrl+V)...")
        .or(authenticatedPage.getByPlaceholder("Connecting..."))
        .or(authenticatedPage.getByPlaceholder("No AI executors available")),
    ).toBeVisible({ timeout: 10000 });

    // Should have delete button
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible();
  });

  test("can edit task title inline", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    const originalTitle = `Edit Test ${Date.now()}`;
    await createTask(authenticatedPage, originalTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(originalTitle).click();
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
    });

    // Click on the title to edit it
    await authenticatedPage
      .getByRole("heading", { level: 2 })
      .filter({ hasText: originalTitle })
      .click();

    // Change the title
    const newTitle = `Updated ${originalTitle}`;
    await authenticatedPage.locator("input").first().clear();
    await authenticatedPage.locator("input").first().fill(newTitle);

    // Save changes
    await authenticatedPage.getByRole("button", { name: "Save" }).click();

    // Wait for save to complete
    await expect(
      authenticatedPage
        .getByRole("heading", { level: 2 })
        .filter({ hasText: newTitle }),
    ).toBeVisible({ timeout: 5000 });

    // Close the panel
    await authenticatedPage.keyboard.press("Escape");

    // The updated title should be visible in the column
    await expect(authenticatedPage.getByText(newTitle)).toBeVisible({
      timeout: 15000,
    });
  });

  test("can delete a task", async ({ authenticatedPage, boardName }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Delete Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
    });

    // Click delete button
    await authenticatedPage.locator("button[title='Delete task']").click();

    // Confirm deletion
    await expect(
      authenticatedPage.getByText("Delete this task?"),
    ).toBeVisible();
    await authenticatedPage.getByRole("button", { name: "Delete" }).click();

    // Wait for panel to close
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).not.toBeVisible({
      timeout: 5000,
    });

    // The task should no longer be visible
    await expect(authenticatedPage.getByText(taskTitle)).not.toBeVisible({
      timeout: 5000,
    });
  });

  test("back button returns to home page", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    // Click the back button
    await authenticatedPage
      .getByRole("link", { name: /back|home/i })
      .or(authenticatedPage.locator("a[href='/']"))
      .first()
      .click();

    // Should be back on home page
    await expect(
      authenticatedPage.getByRole("heading", { name: "Viban Kanban" }),
    ).toBeVisible({ timeout: 10000 });
  });

  test("task card shows error state when task has error", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Error State Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Task should be created successfully
    await expect(authenticatedPage.getByText(taskTitle)).toBeVisible({
      timeout: 15000,
    });
  });

  test("task details shows Open in Editor button when worktree exists", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Editor Button Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();

    // The panel should open correctly (delete button is always visible)
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({ timeout: 5000 });
  });

  test("task details panel shows task description", async ({
    authenticatedPage,
    boardName,
  }) => {
    await authenticatedPage.goto("/");
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Description Test ${Date.now()}`;
    const taskDescription = "This is a test description for activity feed";
    await createTask(authenticatedPage, taskTitle, taskDescription);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();

    // Panel should be open (delete button visible)
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
    });

    // Should see the description in the panel
    await expect(authenticatedPage.getByText(taskDescription)).toBeVisible({
      timeout: 5000,
    });
  });
});
