import { createSignal, For, Show } from "solid-js";
import { CloseIcon } from "./ui/Icons";

/**
 * Inline image data for task descriptions.
 * - `id`: Unique identifier like "img-1", "img-2"
 * - `dataUrl`: Base64 data URL (only for new images, empty for persisted)
 * - `name`: Original filename or generated name
 * - `path`: File path on server (only for persisted images)
 */
export interface InlineImage {
  id: string;
  dataUrl?: string;
  name: string;
  path?: string;
}

/** API format for description images from the backend */
export interface ApiDescriptionImage {
  id?: string;
  path?: string;
  name?: string;
}

/** API format for submitting images */
export interface ApiImagePayload {
  id: string;
  name: string;
  dataUrl?: string;
}

interface ImageTextareaProps {
  /** The text value with placeholders like ![img-1]() */
  value: string;
  /** Called when text changes */
  onChange: (value: string) => void;
  /** Array of inline images */
  images: InlineImage[];
  /** Called when images change */
  onImagesChange: (images: InlineImage[]) => void;
  /** Placeholder text */
  placeholder?: string;
  /** Number of rows */
  rows?: number;
  /** Additional CSS classes for the textarea */
  class?: string;
  /** Whether the textarea is disabled */
  disabled?: boolean;
  /** ID for the textarea */
  id?: string;
  /** Autofocus */
  autofocus?: boolean;
}

/** Get the next available image ID */
const getNextImageId = (images: InlineImage[]): string => {
  const existingNums = images
    .map((img) => {
      const match = img.id.match(/^img-(\d+)$/);
      return match ? parseInt(match[1], 10) : 0;
    })
    .filter((n) => n > 0);

  const maxNum = existingNums.length > 0 ? Math.max(...existingNums) : 0;
  return `img-${maxNum + 1}`;
};

/** Convert a File to a data URL */
const fileToDataUrl = (file: File): Promise<string> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
};

/**
 * A textarea component that supports inline image placeholders.
 *
 * When an image is pasted (Ctrl+V), it:
 * 1. Inserts `![img-N]()` at the cursor position
 * 2. Adds the image to the images array
 * 3. Shows a thumbnail strip below the textarea
 *
 * Usage:
 * ```tsx
 * const [text, setText] = createSignal("");
 * const [images, setImages] = createSignal<InlineImage[]>([]);
 *
 * <ImageTextarea
 *   value={text()}
 *   onChange={setText}
 *   images={images()}
 *   onImagesChange={setImages}
 *   placeholder="Describe the task..."
 * />
 * ```
 */
export default function ImageTextarea(props: ImageTextareaProps) {
  let textareaRef: HTMLTextAreaElement | undefined;
  const [isDragging, setIsDragging] = createSignal(false);

  const handlePaste = async (e: ClipboardEvent) => {
    const items = e.clipboardData?.items;
    if (!items) return;

    const imageItems: DataTransferItem[] = [];
    for (let i = 0; i < items.length; i++) {
      if (items[i].type.startsWith("image/")) {
        imageItems.push(items[i]);
      }
    }

    if (imageItems.length === 0) return;

    // Prevent default to stop the image from being pasted as data
    e.preventDefault();

    for (const item of imageItems) {
      const file = item.getAsFile();
      if (!file) continue;

      try {
        await addImageFromFile(file);
      } catch (err) {
        console.error("Failed to process pasted image:", err);
      }
    }
  };

  const handleDrop = async (e: DragEvent) => {
    e.preventDefault();
    setIsDragging(false);

    const files = e.dataTransfer?.files;
    if (!files) return;

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      if (file.type.startsWith("image/")) {
        try {
          await addImageFromFile(file);
        } catch (err) {
          console.error("Failed to process dropped image:", err);
        }
      }
    }
  };

  const addImageFromFile = async (file: File) => {
    const dataUrl = await fileToDataUrl(file);
    const imageId = getNextImageId(props.images);
    const name = file.name || `screenshot-${Date.now()}.png`;

    const newImage: InlineImage = {
      id: imageId,
      dataUrl,
      name,
    };

    // Insert placeholder at cursor position
    const textarea = textareaRef;
    if (textarea) {
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      const text = props.value;
      const placeholder = `![${imageId}]()`;

      const newText =
        text.substring(0, start) + placeholder + text.substring(end);
      props.onChange(newText);

      // Update cursor position after the placeholder
      requestAnimationFrame(() => {
        const newPos = start + placeholder.length;
        textarea.selectionStart = newPos;
        textarea.selectionEnd = newPos;
        textarea.focus();
      });
    }

    // Add image to the list
    props.onImagesChange([...props.images, newImage]);
  };

  const handleDragOver = (e: DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const removeImage = (imageId: string) => {
    // Remove image from list
    props.onImagesChange(props.images.filter((img) => img.id !== imageId));

    // Also remove the placeholder from text
    const placeholder = `![${imageId}]()`;
    props.onChange(props.value.replaceAll(placeholder, ""));
  };

  const insertPlaceholder = (imageId: string) => {
    const textarea = textareaRef;
    if (!textarea) return;

    const placeholder = `![${imageId}]()`;

    // Check if placeholder already exists in text
    if (props.value.includes(placeholder)) return;

    const start = textarea.selectionStart;
    const text = props.value;

    const newText =
      text.substring(0, start) + placeholder + text.substring(start);
    props.onChange(newText);

    // Update cursor position
    requestAnimationFrame(() => {
      const newPos = start + placeholder.length;
      textarea.selectionStart = newPos;
      textarea.selectionEnd = newPos;
      textarea.focus();
    });
  };

  /** Get the display source for an image (dataUrl or server URL) */
  const getImageSrc = (image: InlineImage): string => {
    if (image.dataUrl) return image.dataUrl;
    if (image.path) return image.path; // Will be transformed to API URL by parent
    return "";
  };

  return (
    <div class="space-y-2">
      <div
        class={`relative ${isDragging() ? "ring-2 ring-brand-500 ring-offset-2 ring-offset-gray-900" : ""}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
      >
        <textarea
          ref={textareaRef}
          id={props.id}
          value={props.value}
          onInput={(e) => props.onChange(e.currentTarget.value)}
          onPaste={handlePaste}
          placeholder={props.placeholder}
          rows={props.rows ?? 4}
          disabled={props.disabled}
          autofocus={props.autofocus}
          class={`w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none ${props.class ?? ""}`}
        />
        <Show when={isDragging()}>
          <div class="absolute inset-0 flex items-center justify-center bg-gray-800/90 border-2 border-dashed border-brand-500 rounded-lg pointer-events-none">
            <div class="text-brand-400 font-medium">Drop image here</div>
          </div>
        </Show>
      </div>

      {/* Image thumbnails strip */}
      <Show when={props.images.length > 0}>
        <div class="flex flex-wrap gap-2 p-2 bg-gray-800/50 border border-gray-700 rounded-lg">
          <For each={props.images}>
            {(image) => {
              const isInText = () => props.value.includes(`![${image.id}]()`);
              return (
                <div
                  class={`relative group flex items-center gap-2 px-2 py-1 rounded border ${
                    isInText()
                      ? "bg-gray-700/50 border-gray-600"
                      : "bg-yellow-500/10 border-yellow-500/30"
                  }`}
                >
                  <img
                    src={getImageSrc(image)}
                    alt={image.name}
                    class="h-8 w-8 object-cover rounded cursor-pointer"
                    onClick={() => insertPlaceholder(image.id)}
                    title={
                      isInText()
                        ? image.name
                        : `Click to insert ${image.id} at cursor`
                    }
                  />
                  <span
                    class={`text-xs font-mono ${isInText() ? "text-gray-400" : "text-yellow-400"}`}
                  >
                    {image.id}
                  </span>
                  <Show when={!isInText()}>
                    <span class="text-xs text-yellow-500" title="Not in text">
                      !
                    </span>
                  </Show>
                  <button
                    type="button"
                    onClick={() => removeImage(image.id)}
                    class="ml-1 text-gray-500 hover:text-red-400 transition-colors"
                    title="Remove image"
                  >
                    <CloseIcon class="w-4 h-4" />
                  </button>
                </div>
              );
            }}
          </For>
        </div>
      </Show>

      <p class="text-xs text-gray-500">
        Paste images with Ctrl+V to embed them inline. Use{" "}
        <code class="bg-gray-800 px-1 rounded">![img-N]()</code> syntax in text.
      </p>
    </div>
  );
}

/**
 * Render markdown description with inline images.
 * Replaces ![img-N]() placeholders with actual img tags.
 *
 * @param description - The markdown text with placeholders
 * @param images - Array of inline images
 * @param taskId - Task ID for building image URLs (for persisted images)
 * @returns HTML string with images embedded
 */
export function renderDescriptionWithImages(
  description: string,
  images: InlineImage[],
  taskId?: string,
): string {
  let result = description;

  for (const img of images) {
    const placeholder = `![${img.id}]()`;
    // Use dataUrl for new images, or API URL for persisted images
    let src = img.dataUrl;
    if (!src && taskId) {
      src = `/api/tasks/${taskId}/images/${img.id}`;
    }
    if (src) {
      const imgTag = `<img src="${src}" alt="${img.name}" class="inline-image max-w-full max-h-64 rounded my-2" loading="lazy" />`;
      result = result.replaceAll(placeholder, imgTag);
    }
  }

  return result;
}

/**
 * Parse description_images from the API format to InlineImage array
 */
export function parseDescriptionImages(
  apiImages: ApiDescriptionImage[] | null | undefined,
): InlineImage[] {
  if (!apiImages) return [];
  return apiImages.map((img) => ({
    id: img.id ?? "img-0",
    name: img.name ?? "image",
    path: img.path,
  }));
}

/**
 * Prepare images for API submission.
 * Only includes dataUrl for new images (ones without path).
 */
export function prepareImagesForApi(images: InlineImage[]): ApiImagePayload[] {
  return images.map((img) => ({
    id: img.id,
    name: img.name,
    // Only send dataUrl for new images
    ...(img.dataUrl && !img.path ? { dataUrl: img.dataUrl } : {}),
  }));
}
