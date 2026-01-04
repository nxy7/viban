import { createSignal } from "solid-js";
import type { Meta, StoryObj } from "storybook-solidjs-vite";
import Select from "./Select";

const meta = {
  title: "Design System/Select",
  component: Select,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    variant: {
      control: "select",
      options: ["default", "dark", "minimal"],
    },
    selectSize: {
      control: "select",
      options: ["sm", "md", "lg"],
    },
    fullWidth: { control: "boolean" },
    disabled: { control: "boolean" },
  },
} satisfies Meta<typeof Select>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    children: (
      <>
        <option value="">Select an option</option>
        <option value="1">Option 1</option>
        <option value="2">Option 2</option>
        <option value="3">Option 3</option>
      </>
    ),
  },
};

export const Dark: Story = {
  args: {
    variant: "dark",
    children: (
      <>
        <option value="">Select an option</option>
        <option value="1">Option 1</option>
        <option value="2">Option 2</option>
        <option value="3">Option 3</option>
      </>
    ),
  },
};

export const Minimal: Story = {
  args: {
    variant: "minimal",
    children: (
      <>
        <option value="">Select an option</option>
        <option value="1">Option 1</option>
        <option value="2">Option 2</option>
        <option value="3">Option 3</option>
      </>
    ),
  },
};

export const Small: Story = {
  args: {
    selectSize: "sm",
    children: (
      <>
        <option value="">Select</option>
        <option value="1">Option 1</option>
        <option value="2">Option 2</option>
      </>
    ),
  },
};

export const Medium: Story = {
  args: {
    selectSize: "md",
    children: (
      <>
        <option value="">Select</option>
        <option value="1">Option 1</option>
        <option value="2">Option 2</option>
      </>
    ),
  },
};

export const Large: Story = {
  args: {
    selectSize: "lg",
    children: (
      <>
        <option value="">Select</option>
        <option value="1">Option 1</option>
        <option value="2">Option 2</option>
      </>
    ),
  },
};

export const FullWidth: Story = {
  args: {
    fullWidth: true,
    children: (
      <>
        <option value="">Select an option</option>
        <option value="1">Option 1</option>
        <option value="2">Option 2</option>
        <option value="3">Option 3</option>
      </>
    ),
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
    children: (
      <>
        <option value="">Select an option</option>
        <option value="1">Option 1</option>
        <option value="2">Option 2</option>
      </>
    ),
  },
};

function InteractiveSelect() {
  const [value, setValue] = createSignal("");
  return (
    <div class="flex flex-col gap-2">
      <Select value={value()} onChange={(e) => setValue(e.currentTarget.value)}>
        <option value="">Select a priority</option>
        <option value="low">Low</option>
        <option value="medium">Medium</option>
        <option value="high">High</option>
        <option value="urgent">Urgent</option>
      </Select>
      <span class="text-sm text-gray-400">Selected: {value() || "none"}</span>
    </div>
  );
}

export const Interactive: Story = {
  render: () => <InteractiveSelect />,
};

export const AllVariants: Story = {
  render: () => (
    <div class="flex flex-col gap-4">
      <Select variant="default">
        <option value="">Default</option>
        <option value="1">Option 1</option>
      </Select>
      <Select variant="dark">
        <option value="">Dark</option>
        <option value="1">Option 1</option>
      </Select>
      <Select variant="minimal">
        <option value="">Minimal</option>
        <option value="1">Option 1</option>
      </Select>
    </div>
  ),
};

export const AllSizes: Story = {
  render: () => (
    <div class="flex flex-col gap-4">
      <Select selectSize="sm">
        <option value="">Small</option>
        <option value="1">Option 1</option>
      </Select>
      <Select selectSize="md">
        <option value="">Medium</option>
        <option value="1">Option 1</option>
      </Select>
      <Select selectSize="lg">
        <option value="">Large</option>
        <option value="1">Option 1</option>
      </Select>
    </div>
  ),
};
