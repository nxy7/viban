import { createBoard, createTask, expect, test } from "./fixtures";

const createTestImageBase64 = (): string => {
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

test.describe("Task Image Support E2E Tests", () => {
  test("can paste image and see thumbnail in chat input", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Image Paste Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    await authenticatedPage.getByText(taskTitle).click();
    await expect(authenticatedPage.getByText("Task Created")).toBeVisible({
      timeout: 5000,
    });

    const chatInput = authenticatedPage.getByPlaceholder(
      /Enter a prompt or paste an image/i,
    );
    await expect(chatInput).toBeVisible({ timeout: 15000 });

    await chatInput.focus();

    const imageDataUrl = createTestImageBase64();

    await authenticatedPage.evaluate(async (dataUrl: string) => {
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

    await authenticatedPage.waitForTimeout(500);

    const thumbnail = authenticatedPage.locator("img.object-cover").first();
    await expect(thumbnail).toBeVisible({ timeout: 5000 });

    const removeButton = authenticatedPage
      .locator('button[title="Remove image"]')
      .first();
    await expect(removeButton).toBeVisible();
  });

  test("can remove attached image before sending", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Image Remove Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    await authenticatedPage.getByText(taskTitle).click();
    await expect(authenticatedPage.getByText("Task Created")).toBeVisible({
      timeout: 5000,
    });

    const chatInput = authenticatedPage.getByPlaceholder(
      /Enter a prompt or paste an image/i,
    );
    await expect(chatInput).toBeVisible({ timeout: 15000 });

    await chatInput.focus();

    const imageDataUrl = createTestImageBase64();

    await authenticatedPage.evaluate(async (dataUrl: string) => {
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

    await authenticatedPage.waitForTimeout(500);
    const thumbnail = authenticatedPage.locator("img.object-cover").first();
    await expect(thumbnail).toBeVisible({ timeout: 5000 });

    const removeButton = authenticatedPage
      .locator('button[title="Remove image"]')
      .first();
    await removeButton.click();

    await expect(thumbnail).not.toBeVisible({ timeout: 2000 });
  });

  test("placeholder text mentions image paste capability", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Placeholder Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    await authenticatedPage.getByText(taskTitle).click();
    await expect(authenticatedPage.getByText("Task Created")).toBeVisible({
      timeout: 5000,
    });

    const chatInput = authenticatedPage.getByPlaceholder(/paste an image/i);
    await expect(chatInput).toBeVisible({ timeout: 15000 });
  });

  test("send button enabled when only image is attached (no text)", async ({
    authenticatedPage,
    boardName,
  }) => {
    await createBoard(authenticatedPage, boardName);

    const taskTitle = `Image Only Send Test ${Date.now()}`;
    await createTask(authenticatedPage, taskTitle);

    await authenticatedPage.getByText(taskTitle).click();
    await expect(authenticatedPage.getByText("Task Created")).toBeVisible({
      timeout: 5000,
    });

    const chatInput = authenticatedPage.getByPlaceholder(
      /Enter a prompt or paste an image/i,
    );
    await expect(chatInput).toBeVisible({ timeout: 15000 });

    const sendButton = authenticatedPage.locator("form button[type='submit']");
    await expect(sendButton).toBeDisabled();

    await chatInput.focus();
    const imageDataUrl = createTestImageBase64();

    await authenticatedPage.evaluate(async (dataUrl: string) => {
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

    await authenticatedPage.waitForTimeout(500);
    await expect(
      authenticatedPage.locator("img.object-cover").first(),
    ).toBeVisible({
      timeout: 5000,
    });

    await expect(sendButton).toBeEnabled();
  });
});
