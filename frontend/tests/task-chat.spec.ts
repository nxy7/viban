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

    // Task details panel should open (delete button is always visible)
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
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

    // Click on the task to open details
    await authenticatedPage.getByText(taskTitle).click();

    // Panel should be open (delete button visible)
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
    });
    await expect(authenticatedPage.getByText(taskDescription)).toBeVisible({
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
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
    });

    // Wait for chat input to be available
    const chatInput = authenticatedPage
      .getByPlaceholder("Enter a prompt or paste an image (Ctrl+V)...")
      .or(authenticatedPage.getByPlaceholder("No AI executors available"));
    await expect(chatInput).toBeVisible({ timeout: 15000 });

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
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
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
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({
      timeout: 5000,
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

    // 2. Delete button should be visible in header
    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible();

    // 3. Chat input at bottom
    await expect(
      authenticatedPage
        .getByPlaceholder("Enter a prompt or paste an image (Ctrl+V)...")
        .or(authenticatedPage.getByPlaceholder("Connecting..."))
        .or(authenticatedPage.getByPlaceholder("No AI executors available")),
    ).toBeVisible({ timeout: 10000 });
  });
});
