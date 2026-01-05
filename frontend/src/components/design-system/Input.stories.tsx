import type { Meta, StoryFn, StoryObj } from "storybook-solidjs-vite";
import Input from "./Input";

const meta = {
  title: "Design System/Input",
  component: Input,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    variant: {
      control: "select",
      options: ["default", "search", "mono", "dark", "dark-mono"],
    },
    inputSize: {
      control: "select",
      options: ["sm", "md", "lg"],
    },
    fullWidth: { control: "boolean" },
    hasIcon: { control: "boolean" },
    disabled: { control: "boolean" },
    placeholder: { control: "text" },
  },
} satisfies Meta<typeof Input>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    placeholder: "Enter text...",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const Search: Story = {
  args: {
    variant: "search",
    placeholder: "Search...",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const Mono: Story = {
  args: {
    variant: "mono",
    placeholder: "Enter code...",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const Dark: Story = {
  args: {
    variant: "dark",
    placeholder: "Dark input...",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const DarkMono: Story = {
  args: {
    variant: "dark-mono",
    placeholder: "Dark mono input...",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const Small: Story = {
  args: {
    inputSize: "sm",
    placeholder: "Small input",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const Medium: Story = {
  args: {
    inputSize: "md",
    placeholder: "Medium input",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const Large: Story = {
  args: {
    inputSize: "lg",
    placeholder: "Large input",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const WithIcon: Story = {
  render: () => (
    <div class="w-64 relative">
      <svg
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
        />
      </svg>
      <Input hasIcon placeholder="Search..." />
    </div>
  ),
};

export const Disabled: Story = {
  args: {
    disabled: true,
    placeholder: "Disabled input",
    value: "Cannot edit this",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const WithValue: Story = {
  args: {
    value: "Hello World",
  },
  decorators: [
    (Story: StoryFn) => (
      <div class="w-64">
        <Story />
      </div>
    ),
  ],
};

export const AllVariants: Story = {
  render: () => (
    <div class="flex flex-col gap-4 w-64">
      <Input variant="default" placeholder="Default" />
      <Input variant="search" placeholder="Search" />
      <Input variant="mono" placeholder="Mono" />
      <Input variant="dark" placeholder="Dark" />
      <Input variant="dark-mono" placeholder="Dark Mono" />
    </div>
  ),
};

export const AllSizes: Story = {
  render: () => (
    <div class="flex flex-col gap-4 w-64">
      <Input inputSize="sm" placeholder="Small" />
      <Input inputSize="md" placeholder="Medium" />
      <Input inputSize="lg" placeholder="Large" />
    </div>
  ),
};
