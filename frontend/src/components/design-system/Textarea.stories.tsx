import { createSignal } from "solid-js";
import type { Meta, StoryObj } from "storybook-solidjs-vite";
import Textarea from "./Textarea";

const meta = {
  title: "Design System/Textarea",
  component: Textarea,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    variant: {
      control: "select",
      options: ["default", "mono", "dark", "dark-mono"],
    },
    textareaSize: {
      control: "select",
      options: ["sm", "md", "lg"],
    },
    fullWidth: { control: "boolean" },
    resizable: { control: "boolean" },
    disabled: { control: "boolean" },
    placeholder: { control: "text" },
    rows: { control: "number" },
  },
} satisfies Meta<typeof Textarea>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    placeholder: "Enter your text...",
    rows: 4,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const Mono: Story = {
  args: {
    variant: "mono",
    placeholder: "Enter code...",
    rows: 4,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const Dark: Story = {
  args: {
    variant: "dark",
    placeholder: "Dark textarea...",
    rows: 4,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const DarkMono: Story = {
  args: {
    variant: "dark-mono",
    placeholder: "Dark mono textarea...",
    rows: 4,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const Small: Story = {
  args: {
    textareaSize: "sm",
    placeholder: "Small textarea",
    rows: 3,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const Medium: Story = {
  args: {
    textareaSize: "md",
    placeholder: "Medium textarea",
    rows: 3,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const Large: Story = {
  args: {
    textareaSize: "lg",
    placeholder: "Large textarea",
    rows: 3,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const NotResizable: Story = {
  args: {
    resizable: false,
    placeholder: "This textarea cannot be resized",
    rows: 4,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const Disabled: Story = {
  args: {
    disabled: true,
    value: "This textarea is disabled and cannot be edited.",
    rows: 4,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const WithValue: Story = {
  args: {
    value: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
    rows: 4,
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

function InteractiveTextarea() {
  const [value, setValue] = createSignal("");
  return (
    <div class="flex flex-col gap-2 w-80">
      <Textarea
        value={value()}
        onInput={(e) => setValue(e.currentTarget.value)}
        placeholder="Type something..."
        rows={4}
      />
      <span class="text-sm text-gray-400">
        Characters: {value().length}
      </span>
    </div>
  );
}

export const Interactive: Story = {
  render: () => <InteractiveTextarea />,
};

export const AllVariants: Story = {
  render: () => (
    <div class="flex flex-col gap-4 w-80">
      <Textarea variant="default" placeholder="Default" rows={2} />
      <Textarea variant="mono" placeholder="Mono" rows={2} />
      <Textarea variant="dark" placeholder="Dark" rows={2} />
      <Textarea variant="dark-mono" placeholder="Dark Mono" rows={2} />
    </div>
  ),
};

export const AllSizes: Story = {
  render: () => (
    <div class="flex flex-col gap-4 w-80">
      <Textarea textareaSize="sm" placeholder="Small" rows={2} />
      <Textarea textareaSize="md" placeholder="Medium" rows={2} />
      <Textarea textareaSize="lg" placeholder="Large" rows={2} />
    </div>
  ),
};

export const CodeEditor: Story = {
  render: () => (
    <div class="w-96">
      <Textarea
        variant="dark-mono"
        value={`function greet(name) {
  return \`Hello, \${name}!\`;
}

console.log(greet("World"));`}
        rows={6}
        resizable={false}
      />
    </div>
  ),
};
