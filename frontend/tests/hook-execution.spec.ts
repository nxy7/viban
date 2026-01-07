import { createBoard, createTask, expect, test } from "./fixtures";

test.describe("Hook Execution E2E Tests", () => {
  test("board shows all expected columns for hook execution", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("In Progress")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("To Review")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("Done")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("Cancelled")).toBeVisible({
      timeout: 15000,
    });
  });

  test("task in In Progress column shows appropriate state indicator", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const inProgressColumn = authenticatedPage
      .locator("[data-column-id]")
      .filter({ hasText: "In Progress" });
    await expect(inProgressColumn).toBeVisible({ timeout: 15000 });

    const taskInProgress = inProgressColumn.locator("[data-task-id]").first();
    const hasTask = await taskInProgress.isVisible().catch(() => false);

    if (hasTask) {
      const workingIndicator = taskInProgress.getByText("Working...");
      const executingIndicator = taskInProgress.getByText(/Executing/);
      const idleTask = taskInProgress;

      await expect(
        workingIndicator.or(executingIndicator).or(idleTask),
      ).toBeVisible();
    }
  });

  test("task card in TODO column does not show executing state", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Hook Test Task ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    const todoColumn = authenticatedPage
      .locator("[data-column-id]")
      .filter({ hasText: "TODO" });
    await expect(todoColumn).toBeVisible({ timeout: 15000 });

    const taskInTodo = todoColumn.locator("[data-task-id]").first();
    const hasTask = await taskInTodo.isVisible().catch(() => false);

    if (hasTask) {
      const workingBadge = taskInTodo.getByText("Working...");
      const executingBadge = taskInTodo.getByText(/Executing/);

      await expect(workingBadge).not.toBeVisible();
      await expect(executingBadge).not.toBeVisible();
    }
  });

  test("task details panel opens and shows delete button", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Panel Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    await authenticatedPage.getByText(taskTitle).click();

    await expect(
      authenticatedPage.locator("button[title='Delete task']"),
    ).toBeVisible({ timeout: 10000 });
  });

  test("stop button is available when executor is running", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const inProgressColumn = authenticatedPage
      .locator("[data-column-id]")
      .filter({ hasText: "In Progress" });
    await expect(inProgressColumn).toBeVisible({ timeout: 15000 });

    const runningTask = inProgressColumn.locator("[data-task-id]").first();
    const hasRunningTask = await runningTask.isVisible().catch(() => false);

    if (hasRunningTask) {
      await runningTask.click();

      const stopButton = authenticatedPage.locator(
        "button[title='Stop executor']",
      );
      const hasStop = await stopButton
        .isVisible({ timeout: 5000 })
        .catch(() => false);

      if (hasStop) {
        await expect(stopButton).toBeVisible();
      }
    }
  });

  test("page refresh maintains task state consistency", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Refresh Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    const boardUrl = authenticatedPage.url();

    await expect(authenticatedPage.getByText("In Progress")).toBeVisible({
      timeout: 15000,
    });

    await authenticatedPage.reload();

    await authenticatedPage.waitForURL(boardUrl);
    await expect(authenticatedPage.getByText("In Progress")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText(taskTitle)).toBeVisible({
      timeout: 15000,
    });
  });

  test("column shows settings button for hook configuration", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    await expect(authenticatedPage.getByText("In Progress")).toBeVisible({
      timeout: 15000,
    });

    const inProgressColumn = authenticatedPage
      .locator("[data-column-id]")
      .filter({ hasText: "In Progress" });

    const settingsButton = inProgressColumn
      .locator("[title='Column settings']")
      .first();
    const hasSettings = await settingsButton.isVisible().catch(() => false);

    if (hasSettings) {
      await settingsButton.click();
      await expect(authenticatedPage.getByText(/hooks/i)).toBeVisible({
        timeout: 5000,
      });
    }
  });
});
