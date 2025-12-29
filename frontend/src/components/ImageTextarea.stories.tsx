import { createSignal } from "solid-js";
import type { Meta, StoryObj } from "storybook-solidjs-vite";
import ImageTextarea, { type InlineImage } from "./ImageTextarea";

const meta = {
  title: "Components/ImageTextarea",
  component: ImageTextarea,
  parameters: {
    layout: "padded",
  },
  tags: ["autodocs"],
  argTypes: {
    placeholder: { control: "text" },
    rows: { control: "number" },
    disabled: { control: "boolean" },
  },
} satisfies Meta<typeof ImageTextarea>;

export default meta;
type Story = StoryObj<typeof meta>;

// Wrapper component to manage state for stories
function ImageTextareaWrapper(props: {
  placeholder?: string;
  rows?: number;
  disabled?: boolean;
  initialValue?: string;
  initialImages?: InlineImage[];
}) {
  const [value, setValue] = createSignal(props.initialValue ?? "");
  const [images, setImages] = createSignal<InlineImage[]>(
    props.initialImages ?? [],
  );

  return (
    <div class="w-full max-w-2xl bg-gray-900 p-4 rounded-lg">
      <ImageTextarea
        value={value()}
        onChange={setValue}
        images={images()}
        onImagesChange={setImages}
        placeholder={props.placeholder}
        rows={props.rows}
        disabled={props.disabled}
      />
      <div class="mt-4 text-xs text-gray-500">
        <div>Value: {JSON.stringify(value())}</div>
        <div>Images: {JSON.stringify(images())}</div>
      </div>
    </div>
  );
}

export const Empty: Story = {
  render: () => <ImageTextareaWrapper placeholder="Type here..." rows={4} />,
};

export const WithText: Story = {
  render: () => (
    <ImageTextareaWrapper
      initialValue="This is a description with some text."
      placeholder="Type here..."
      rows={4}
    />
  ),
};

export const WithImage: Story = {
  render: () => (
    <ImageTextareaWrapper
      initialValue="Check out this screenshot ![img-1]() and let me know what you think."
      initialImages={[
        {
          id: "img-1",
          dataUrl:
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
          name: "screenshot.png",
        },
      ]}
      placeholder="Type here..."
      rows={4}
    />
  ),
};

export const WithMultipleImages: Story = {
  render: () => (
    <ImageTextareaWrapper
      initialValue="Compare ![img-1]() and ![img-2]() - which one looks better?"
      initialImages={[
        {
          id: "img-1",
          dataUrl:
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==",
          name: "image1.png",
        },
        {
          id: "img-2",
          dataUrl:
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPj/HwADBwIAMCbHYQAAAABJRU5ErkJggg==",
          name: "image2.png",
        },
      ]}
      placeholder="Type here..."
      rows={4}
    />
  ),
};

export const UnreferencedImage: Story = {
  render: () => (
    <ImageTextareaWrapper
      initialValue="I pasted an image but forgot to reference it."
      initialImages={[
        {
          id: "img-1",
          dataUrl:
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
          name: "unreferenced.png",
        },
      ]}
      placeholder="Type here..."
      rows={4}
    />
  ),
};

export const Disabled: Story = {
  render: () => (
    <ImageTextareaWrapper
      initialValue="This textarea is disabled."
      placeholder="Type here..."
      rows={4}
      disabled
    />
  ),
};
