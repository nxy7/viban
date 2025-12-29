import { expect, test } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";

test.describe("Task Image Support E2E Tests", () => {
  // Helper to create a simple red square PNG as base64
  const createTestImageBase64 = (): string => {
    // This is a minimal valid 10x10 red PNG image
    const redSquarePng = Buffer.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x0a,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x02, 0x50, 0x58, 0xea, 0x00, 0x00, 0x00,
      0x1c, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x62, 0xf8, 0xcf, 0xc0, 0xc0,
      0xc0, 0xc4, 0xc0, 0xc0, 0xc0, 0xc4, 0xc0, 0xc0, 0xc0, 0xc4, 0xc0, 0xc0,
      0xc0, 0x04, 0x00, 0x35, 0x95, 0x01, 0xbd, 0xa2, 0x2d, 0x77, 0x10, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
    ]);
    return `data:image/png;base64,${redSquarePng.toString("base64")}`;
  };

  test("can paste image and see thumbnail in chat input", async ({ page }) => {
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

    const taskTitle = `Image Paste Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Wait for chat input to be ready
    const chatInput = page.getByPlaceholder(
      /Enter a prompt or paste an image/i,
    );
    await expect(chatInput).toBeVisible({ timeout: 15000 });

    // Focus the input
    await chatInput.focus();

    // Create a test image and paste it using clipboard API
    const imageDataUrl = createTestImageBase64();

    // We need to simulate a paste event with image data
    // Playwright doesn't directly support pasting images, so we'll use evaluate
    await page.evaluate(async (dataUrl: string) => {
      // Convert data URL to blob
      const response = await fetch(dataUrl);
      const blob = await response.blob();

      // Create a ClipboardItem
      const clipboardItem = new ClipboardItem({
        [blob.type]: blob,
      });

      // Create a paste event
      const dataTransfer = new DataTransfer();

      // Add the file to the dataTransfer
      const file = new File([blob], "test-image.png", { type: "image/png" });
      dataTransfer.items.add(file);

      // Dispatch paste event on the focused textarea
      const textarea = document.activeElement as HTMLTextAreaElement;
      const pasteEvent = new ClipboardEvent("paste", {
        bubbles: true,
        cancelable: true,
        clipboardData: dataTransfer,
      });

      textarea.dispatchEvent(pasteEvent);
    }, imageDataUrl);

    // Wait a moment for the image to be processed
    await page.waitForTimeout(500);

    // Should see an image thumbnail (img element with class containing object-cover)
    const thumbnail = page.locator("img.object-cover").first();
    await expect(thumbnail).toBeVisible({ timeout: 5000 });

    // Should have a remove button (x button on thumbnail)
    const removeButton = page.locator('button[title="Remove image"]').first();
    await expect(removeButton).toBeVisible();
  });

  test("can remove attached image before sending", async ({ page }) => {
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

    const taskTitle = `Image Remove Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Wait for chat input to be ready
    const chatInput = page.getByPlaceholder(
      /Enter a prompt or paste an image/i,
    );
    await expect(chatInput).toBeVisible({ timeout: 15000 });

    // Focus the input
    await chatInput.focus();

    // Create a test image and paste it
    const imageDataUrl = createTestImageBase64();

    await page.evaluate(async (dataUrl: string) => {
      const response = await fetch(dataUrl);
      const blob = await response.blob();
      const dataTransfer = new DataTransfer();
      const file = new File([blob], "test-image.png", { type: "image/png" });
      dataTransfer.items.add(file);
      const textarea = document.activeElement as HTMLTextAreaElement;
      const pasteEvent = new ClipboardEvent("paste", {
        bubbles: true,
        cancelable: true,
        clipboardData: dataTransfer,
      });
      textarea.dispatchEvent(pasteEvent);
    }, imageDataUrl);

    // Wait for thumbnail to appear
    await page.waitForTimeout(500);
    const thumbnail = page.locator("img.object-cover").first();
    await expect(thumbnail).toBeVisible({ timeout: 5000 });

    // Click remove button
    const removeButton = page.locator('button[title="Remove image"]').first();
    await removeButton.click();

    // Thumbnail should be gone
    await expect(thumbnail).not.toBeVisible({ timeout: 2000 });
  });

  test("placeholder text mentions image paste capability", async ({ page }) => {
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

    const taskTitle = `Placeholder Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Wait for chat input - should mention image paste
    const chatInput = page.getByPlaceholder(/paste an image/i);
    await expect(chatInput).toBeVisible({ timeout: 15000 });
  });

  test("send button enabled when only image is attached (no text)", async ({
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

    const taskTitle = `Image Only Send Test ${Date.now()}`;
    await page.getByPlaceholder("Enter task title...").fill(taskTitle);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByPlaceholder("Enter task title...")).not.toBeVisible({
      timeout: 5000,
    });

    // Click on the task to open details
    await page.getByText(taskTitle).click();
    await expect(page.getByText("Task Created")).toBeVisible({ timeout: 5000 });

    // Wait for chat input to be ready
    const chatInput = page.getByPlaceholder(
      /Enter a prompt or paste an image/i,
    );
    await expect(chatInput).toBeVisible({ timeout: 15000 });

    // Initially, send button should be disabled (no text, no image)
    const sendButton = page.locator("form button[type='submit']");
    await expect(sendButton).toBeDisabled();

    // Focus and paste an image
    await chatInput.focus();
    const imageDataUrl = createTestImageBase64();

    await page.evaluate(async (dataUrl: string) => {
      const response = await fetch(dataUrl);
      const blob = await response.blob();
      const dataTransfer = new DataTransfer();
      const file = new File([blob], "test-image.png", { type: "image/png" });
      dataTransfer.items.add(file);
      const textarea = document.activeElement as HTMLTextAreaElement;
      const pasteEvent = new ClipboardEvent("paste", {
        bubbles: true,
        cancelable: true,
        clipboardData: dataTransfer,
      });
      textarea.dispatchEvent(pasteEvent);
    }, imageDataUrl);

    // Wait for thumbnail to appear
    await page.waitForTimeout(500);
    await expect(page.locator("img.object-cover").first()).toBeVisible({
      timeout: 5000,
    });

    // Now send button should be enabled (image attached, even without text)
    await expect(sendButton).toBeEnabled();
  });
});
