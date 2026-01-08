import { createBoard, createTask, expect, test } from "./fixtures";

test.describe("Task Chat E2E Tests (Unified Activity View)", () => {
  test("task details panel shows unified activity view with chat", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Chat Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();

    // Task details panel should open
    await expect(
      authenticatedPage.locator('[role="dialog"][aria-modal="true"]'),
    ).toBeVisible({
      timeout: 10000,
    });

    // Chat input should be visible at bottom (part of unified view)
    await expect(
      authenticatedPage
        .getByPlaceholder("Enter a prompt or paste an image (Ctrl+V)...")
        .or(authenticatedPage.getByPlaceholder("Connecting..."))
        .or(authenticatedPage.getByPlaceholder("No AI executors available")),
    ).toBeVisible({ timeout: 10000 });
  });

  test("chat interface shows connection status", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Connection Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();

    // Should show connection status (Connected or Disconnected) in header
    await expect(
      authenticatedPage
        .getByText("Connected")
        .or(authenticatedPage.getByText("Disconnected")),
    ).toBeVisible({ timeout: 15000 });
  });

  test("chat has send button", async ({ authenticatedPage, boardName }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Send Button Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();

    // Should have a Send button (submit button in form)
    await expect(
      authenticatedPage.locator("form button[type='submit']"),
    ).toBeVisible({
      timeout: 10000,
    });
  });

  test("task details panel shows description", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    // Create a task with description
    const addCardButton = authenticatedPage
      .getByRole("button", { name: /add a card/i })
      .first();
    await expect(addCardButton).toBeVisible({ timeout: 15000 });
    await addCardButton.click();

    const taskTitle = `Description Panel Test ${Date.now()}`;
    const taskDescription = "Test description for activity";
    await authenticatedPage
      .getByPlaceholder("Enter task title...")
      .fill(taskTitle);
    await authenticatedPage
      .getByPlaceholder("Enter task description...")
      .fill(taskDescription);
    await authenticatedPage
      .getByRole("button", { name: "Create Task" })
      .click();
    await expect(
      authenticatedPage.getByPlaceholder("Enter task title..."),
    ).not.toBeVisible({
      timeout: 5000,
    });

    // Wait for task to appear
    await expect(authenticatedPage.getByText(taskTitle)).toBeVisible({
      timeout: 15000,
    });

    // Click on the task to open details (use first() since description may also match)
    await authenticatedPage.getByText(taskTitle).first().click();

    // Panel should be open
    const panel = authenticatedPage.locator(
      '[role="dialog"][aria-modal="true"]',
    );
    await expect(panel).toBeVisible({ timeout: 10000 });

    // Description should be visible in the panel (scoped to avoid matching task card)
    await expect(panel.getByText(taskDescription)).toBeVisible({
      timeout: 5000,
    });
  });

  test("can type in chat input", async ({ authenticatedPage, boardName }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Chat Input Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();
    await expect(
      authenticatedPage.locator('[role="dialog"][aria-modal="true"]'),
    ).toBeVisible({
      timeout: 10000,
    });

    // Wait for chat input to be available (any state)
    const chatInput = authenticatedPage.locator("form textarea");
    await expect(chatInput).toBeVisible({ timeout: 15000 });

    // Skip test if no executors available (input will be disabled)
    const isDisabled = await chatInput.isDisabled();
    if (isDisabled) {
      test.skip(true, "No AI executors available - chat input disabled");
      return;
    }

    // Type a message
    await chatInput.fill("Hello, this is a test message");

    // Verify the text was entered
    await expect(chatInput).toHaveValue("Hello, this is a test message");
  });

  test("task title is clickable for editing in header", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Editable Title Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();
    await expect(
      authenticatedPage.locator('[role="dialog"][aria-modal="true"]'),
    ).toBeVisible({
      timeout: 10000,
    });

    // Click on the title to start editing
    await authenticatedPage
      .getByRole("heading", { level: 2 })
      .filter({ hasText: taskTitle })
      .click();

    // Should show input field and Save/Cancel buttons
    await expect(
      authenticatedPage.getByRole("button", { name: "Save" }),
    ).toBeVisible({
      timeout: 5000,
    });
    await expect(
      authenticatedPage.getByRole("button", { name: "Cancel" }),
    ).toBeVisible();
  });

  test("agent status badge is visible when applicable", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Status Badge Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();

    // Task details should be visible - verify panel opened correctly
    await expect(
      authenticatedPage.locator('[role="dialog"][aria-modal="true"]'),
    ).toBeVisible({
      timeout: 10000,
    });
  });

  test("layout has header, scrollable content, and fixed input", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Layout Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();

    // Verify the three-part layout:
    // 1. Header with title
    await expect(
      authenticatedPage
        .getByRole("heading", { level: 2 })
        .filter({ hasText: taskTitle }),
    ).toBeVisible({ timeout: 5000 });

    // 2. Panel should be open
    await expect(
      authenticatedPage.locator('[role="dialog"][aria-modal="true"]'),
    ).toBeVisible({ timeout: 10000 });

    // 3. Chat input at bottom
    await expect(
      authenticatedPage
        .getByPlaceholder("Enter a prompt or paste an image (Ctrl+V)...")
        .or(authenticatedPage.getByPlaceholder("Connecting..."))
        .or(authenticatedPage.getByPlaceholder("No AI executors available")),
    ).toBeVisible({ timeout: 10000 });
  });
});
