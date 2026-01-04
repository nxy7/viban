import type { Meta, StoryObj } from "storybook-solidjs-vite";
import Button from "./Button";

const meta = {
  title: "Design System/Button",
  component: Button,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    variant: {
      control: "select",
      options: ["primary", "secondary", "danger", "ghost", "icon"],
    },
    buttonSize: {
      control: "select",
      options: ["sm", "md", "lg"],
    },
    fullWidth: { control: "boolean" },
    loading: { control: "boolean" },
    disabled: { control: "boolean" },
  },
} satisfies Meta<typeof Button>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Primary: Story = {
  args: {
    variant: "primary",
    children: "Primary Button",
  },
};

export const Secondary: Story = {
  args: {
    variant: "secondary",
    children: "Secondary Button",
  },
};

export const Danger: Story = {
  args: {
    variant: "danger",
    children: "Delete",
  },
};

export const Ghost: Story = {
  args: {
    variant: "ghost",
    children: "Ghost Button",
  },
};

export const Icon: Story = {
  args: {
    variant: "icon",
    children: (
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
      </svg>
    ),
  },
};

export const Small: Story = {
  args: {
    buttonSize: "sm",
    children: "Small Button",
  },
};

export const Medium: Story = {
  args: {
    buttonSize: "md",
    children: "Medium Button",
  },
};

export const Large: Story = {
  args: {
    buttonSize: "lg",
    children: "Large Button",
  },
};

export const FullWidth: Story = {
  args: {
    fullWidth: true,
    children: "Full Width Button",
  },
  decorators: [
    (Story) => (
      <div class="w-80">
        <Story />
      </div>
    ),
  ],
};

export const Loading: Story = {
  args: {
    loading: true,
    children: "Loading...",
  },
};

export const Disabled: Story = {
  args: {
    disabled: true,
    children: "Disabled Button",
  },
};

export const AllVariants: Story = {
  render: () => (
    <div class="flex flex-col gap-4">
      <div class="flex gap-4 items-center">
        <Button variant="primary">Primary</Button>
        <Button variant="secondary">Secondary</Button>
        <Button variant="danger">Danger</Button>
        <Button variant="ghost">Ghost</Button>
        <Button variant="icon">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
        </Button>
      </div>
    </div>
  ),
};

export const AllSizes: Story = {
  render: () => (
    <div class="flex gap-4 items-center">
      <Button buttonSize="sm">Small</Button>
      <Button buttonSize="md">Medium</Button>
      <Button buttonSize="lg">Large</Button>
    </div>
  ),
};

export const AllStates: Story = {
  render: () => (
    <div class="flex flex-col gap-4">
      <div class="flex gap-4 items-center">
        <Button>Normal</Button>
        <Button disabled>Disabled</Button>
        <Button loading>Loading</Button>
      </div>
      <div class="flex gap-4 items-center">
        <Button variant="secondary">Normal</Button>
        <Button variant="secondary" disabled>Disabled</Button>
        <Button variant="secondary" loading>Loading</Button>
      </div>
      <div class="flex gap-4 items-center">
        <Button variant="danger">Normal</Button>
        <Button variant="danger" disabled>Disabled</Button>
        <Button variant="danger" loading>Loading</Button>
      </div>
    </div>
  ),
};
