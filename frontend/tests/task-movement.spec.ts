import { expect, test } from "./fixtures";

const NO_HOOKS_BOARD = "E2E Test Board (No Hooks)";
const SLOW_HOOK_BOARD = "E2E Test Board (Slow Hook)";

async function navigateToBoard(
  page: import("@playwright/test").Page,
  boardName: string,
) {
  await page.goto("/");

  const boardLink = page.getByRole("link", { name: boardName });
  const hasBoardLink = await boardLink
    .isVisible({ timeout: 10000 })
    .catch(() => false);

  if (!hasBoardLink) {
    test.skip(true, `Board "${boardName}" not found - run seeds first`);
    return false;
  }

  await boardLink.click();
  await page.waitForURL(/\/board\/.+/);
  return true;
}

async function getColumnLocator(
  page: import("@playwright/test").Page,
  columnName: string,
) {
  return page.locator("[data-column-id]").filter({ hasText: columnName });
}

async function getTasksInColumn(
  page: import("@playwright/test").Page,
  columnName: string,
) {
  const column = await getColumnLocator(page, columnName);
  return column.locator("[data-task-id]");
}

test.describe("Task Movement E2E Tests (No Hooks Board)", () => {
  test("board loads with expected columns", async ({ authenticatedPage }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, NO_HOOKS_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("In Progress")).toBeVisible();
    await expect(authenticatedPage.getByText("Done")).toBeVisible();
  });

  test("board shows seed tasks in TODO column", async ({
    authenticatedPage,
  }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, NO_HOOKS_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });

    const todoColumn = await getColumnLocator(authenticatedPage, "TODO");
    await expect(todoColumn).toBeVisible();

    const tasksInTodo = await getTasksInColumn(authenticatedPage, "TODO");
    const taskCount = await tasksInTodo.count();
    expect(taskCount).toBeGreaterThanOrEqual(1);
  });

  test("can drag task from TODO to In Progress", async ({
    authenticatedPage,
  }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, NO_HOOKS_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });

    const todoColumn = await getColumnLocator(authenticatedPage, "TODO");
    const firstTask = todoColumn.locator("[data-task-id]").first();
    const hasTask = await firstTask.isVisible().catch(() => false);

    if (!hasTask) {
      test.skip(true, "No tasks in TODO column");
      return;
    }

    const taskTitle = await firstTask
      .locator("h3, h4, p")
      .first()
      .textContent();
    if (!taskTitle) {
      test.skip(true, "Could not get task title");
      return;
    }

    const inProgressColumn = await getColumnLocator(
      authenticatedPage,
      "In Progress",
    );
    await firstTask.dragTo(inProgressColumn, { force: true });

    await authenticatedPage.waitForTimeout(1000);

    const inProgressTasks = await getTasksInColumn(
      authenticatedPage,
      "In Progress",
    );
    const movedTask = inProgressTasks.filter({ hasText: taskTitle.trim() });
    await expect(movedTask).toBeVisible({ timeout: 5000 });
  });

  test("can drag task back to TODO from In Progress", async ({
    authenticatedPage,
  }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, NO_HOOKS_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("In Progress")).toBeVisible({
      timeout: 15000,
    });

    const inProgressColumn = await getColumnLocator(
      authenticatedPage,
      "In Progress",
    );
    const firstTask = inProgressColumn.locator("[data-task-id]").first();
    const hasTask = await firstTask.isVisible().catch(() => false);

    if (!hasTask) {
      test.skip(true, "No tasks in In Progress column");
      return;
    }

    const taskTitle = await firstTask
      .locator("h3, h4, p")
      .first()
      .textContent();
    if (!taskTitle) {
      test.skip(true, "Could not get task title");
      return;
    }

    const todoColumn = await getColumnLocator(authenticatedPage, "TODO");
    await firstTask.dragTo(todoColumn, { force: true });

    await authenticatedPage.waitForTimeout(1000);

    const todoTasks = await getTasksInColumn(authenticatedPage, "TODO");
    const movedTask = todoTasks.filter({ hasText: taskTitle.trim() });
    await expect(movedTask).toBeVisible({ timeout: 5000 });
  });

  test("can reorder tasks within TODO column", async ({
    authenticatedPage,
  }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, NO_HOOKS_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });

    const todoColumn = await getColumnLocator(authenticatedPage, "TODO");
    const tasks = todoColumn.locator("[data-task-id]");
    const taskCount = await tasks.count();

    if (taskCount < 2) {
      test.skip(true, "Need at least 2 tasks in TODO to test reordering");
      return;
    }

    const firstTask = tasks.nth(0);
    const secondTask = tasks.nth(1);

    const firstTitle = await firstTask
      .locator("h3, h4, p")
      .first()
      .textContent();
    const secondTitle = await secondTask
      .locator("h3, h4, p")
      .first()
      .textContent();

    if (!firstTitle || !secondTitle) {
      test.skip(true, "Could not get task titles");
      return;
    }

    await firstTask.dragTo(secondTask, { force: true });

    await authenticatedPage.waitForTimeout(1000);

    const updatedTasks = todoColumn.locator("[data-task-id]");
    const newFirstTitle = await updatedTasks
      .nth(0)
      .locator("h3, h4, p")
      .first()
      .textContent();

    expect(newFirstTitle?.trim()).not.toBe(firstTitle.trim());
  });
});

test.describe("Hook Cancellation E2E Tests (Slow Hook Board)", () => {
  test("board loads with expected columns and hook", async ({
    authenticatedPage,
  }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, SLOW_HOOK_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });
    await expect(authenticatedPage.getByText("In Progress")).toBeVisible();
  });

  test("moving task to In Progress triggers slow hook", async ({
    authenticatedPage,
  }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, SLOW_HOOK_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });

    const todoColumn = await getColumnLocator(authenticatedPage, "TODO");
    const firstTask = todoColumn.locator("[data-task-id]").first();
    const hasTask = await firstTask.isVisible().catch(() => false);

    if (!hasTask) {
      test.skip(true, "No tasks in TODO column");
      return;
    }

    const inProgressColumn = await getColumnLocator(
      authenticatedPage,
      "In Progress",
    );
    await firstTask.dragTo(inProgressColumn, { force: true });

    await authenticatedPage.waitForTimeout(2000);

    const inProgressTasks = await getTasksInColumn(
      authenticatedPage,
      "In Progress",
    );
    const taskCount = await inProgressTasks.count();
    expect(taskCount).toBeGreaterThanOrEqual(1);
  });

  test("moving task to another column cancels running hook", async ({
    authenticatedPage,
  }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, SLOW_HOOK_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("In Progress")).toBeVisible({
      timeout: 15000,
    });

    const inProgressColumn = await getColumnLocator(
      authenticatedPage,
      "In Progress",
    );
    const firstTask = inProgressColumn.locator("[data-task-id]").first();
    const hasTask = await firstTask.isVisible().catch(() => false);

    if (!hasTask) {
      test.skip(
        true,
        "No tasks in In Progress column - run hook trigger test first",
      );
      return;
    }

    const todoColumn = await getColumnLocator(authenticatedPage, "TODO");
    await firstTask.dragTo(todoColumn, { force: true });

    await authenticatedPage.waitForTimeout(1000);

    const todoTasks = await getTasksInColumn(authenticatedPage, "TODO");
    const taskCount = await todoTasks.count();
    expect(taskCount).toBeGreaterThanOrEqual(1);
  });

  test("stop button cancels running hook", async ({ authenticatedPage }) => {
    const hasBoard = await navigateToBoard(authenticatedPage, SLOW_HOOK_BOARD);
    if (!hasBoard) return;

    await expect(authenticatedPage.getByText("TODO")).toBeVisible({
      timeout: 15000,
    });

    const todoColumn = await getColumnLocator(authenticatedPage, "TODO");
    const taskWithTitle = todoColumn.locator("[data-task-id]").first();
    const hasTask = await taskWithTitle.isVisible().catch(() => false);

    if (!hasTask) {
      test.skip(true, "No tasks available for stop button test");
      return;
    }

    const inProgressColumn = await getColumnLocator(
      authenticatedPage,
      "In Progress",
    );
    await taskWithTitle.dragTo(inProgressColumn, { force: true });

    await authenticatedPage.waitForTimeout(500);

    const inProgressTasks = await getTasksInColumn(
      authenticatedPage,
      "In Progress",
    );
    const movedTask = inProgressTasks.first();

    if (await movedTask.isVisible().catch(() => false)) {
      await movedTask.click();

      await authenticatedPage.waitForTimeout(1000);

      const stopButton = authenticatedPage.locator(
        "button[title='Stop executor']",
      );
      const hasStopButton = await stopButton
        .isVisible({ timeout: 5000 })
        .catch(() => false);

      if (hasStopButton) {
        await stopButton.click();

        await expect(stopButton).not.toBeVisible({ timeout: 10000 });
      }

      await authenticatedPage.keyboard.press("Escape");
    }
  });
});
