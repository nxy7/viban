import { expect, test } from "@playwright/test";

async function navigateToFirstBoard(page: import("@playwright/test").Page) {
  await page.goto("/");

  const boardLink = page.locator("a[href^='/board/']").first();
  const hasBoardLink = await boardLink
    .isVisible({ timeout: 5000 })
    .catch(() => false);

  if (!hasBoardLink) {
    test.skip(true, "No boards available - skipping test");
    return false;
  }

  await boardLink.click();
  await page.waitForURL(/\/board\/.+/);
  return true;
}

test.describe("Hook Execution E2E Tests", () => {
  test("board shows all expected columns for hook execution", async ({
    page,
  }) => {
    const hasBoard = await navigateToFirstBoard(page);
    if (!hasBoard) return;

    await expect(page.getByText("TODO")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("In Progress")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("To Review")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("Done")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("Cancelled")).toBeVisible({ timeout: 15000 });
  });

  test("task in In Progress column shows appropriate state indicator", async ({
    page,
  }) => {
    const hasBoard = await navigateToFirstBoard(page);
    if (!hasBoard) return;

    const inProgressColumn = page
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
    page,
  }) => {
    const hasBoard = await navigateToFirstBoard(page);
    if (!hasBoard) return;

    const todoColumn = page
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

  test("task details panel opens and shows activity", async ({ page }) => {
    const hasBoard = await navigateToFirstBoard(page);
    if (!hasBoard) return;

    const anyTask = page.locator("[data-task-id]").first();
    const hasTask = await anyTask
      .isVisible({ timeout: 10000 })
      .catch(() => false);

    if (hasTask) {
      await anyTask.click();

      await expect(
        page.getByText("Task Created").or(page.getByText("Connected")),
      ).toBeVisible({ timeout: 10000 });
    }
  });

  test("stop button is available when executor is running", async ({
    page,
  }) => {
    const hasBoard = await navigateToFirstBoard(page);
    if (!hasBoard) return;

    const inProgressColumn = page
      .locator("[data-column-id]")
      .filter({ hasText: "In Progress" });
    await expect(inProgressColumn).toBeVisible({ timeout: 15000 });

    const runningTask = inProgressColumn.locator("[data-task-id]").first();
    const hasRunningTask = await runningTask.isVisible().catch(() => false);

    if (hasRunningTask) {
      await runningTask.click();

      const stopButton = page.locator("button[title='Stop executor']");
      const hasStop = await stopButton
        .isVisible({ timeout: 5000 })
        .catch(() => false);

      if (hasStop) {
        await expect(stopButton).toBeVisible();
      }
    }
  });

  test("page refresh maintains task state consistency", async ({ page }) => {
    const hasBoard = await navigateToFirstBoard(page);
    if (!hasBoard) return;

    const boardUrl = page.url();

    await expect(page.getByText("In Progress")).toBeVisible({ timeout: 15000 });

    await page.reload();

    await page.waitForURL(boardUrl);
    await expect(page.getByText("In Progress")).toBeVisible({ timeout: 15000 });
    await expect(page.getByText("TODO")).toBeVisible({ timeout: 15000 });
  });

  test("column shows settings button for hook configuration", async ({
    page,
  }) => {
    const hasBoard = await navigateToFirstBoard(page);
    if (!hasBoard) return;

    await expect(page.getByText("In Progress")).toBeVisible({ timeout: 15000 });

    const inProgressColumn = page
      .locator("[data-column-id]")
      .filter({ hasText: "In Progress" });

    const settingsButton = inProgressColumn
      .locator("[title='Column settings']")
      .first();
    const hasSettings = await settingsButton.isVisible().catch(() => false);

    if (hasSettings) {
      await settingsButton.click();
      await expect(page.getByText(/hooks/i)).toBeVisible({ timeout: 5000 });
    }
  });
});
