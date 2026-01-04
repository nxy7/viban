import { createSignal } from "solid-js";
import type { Meta, StoryObj } from "storybook-solidjs-vite";
import Checkbox from "./Checkbox";

const meta = {
  title: "Design System/Checkbox",
  component: Checkbox,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    checkboxSize: {
      control: "select",
      options: ["sm", "md", "lg"],
    },
    disabled: { control: "boolean" },
    checked: { control: "boolean" },
  },
} satisfies Meta<typeof Checkbox>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {},
};

export const Checked: Story = {
  args: {
    checked: true,
  },
};

export const Small: Story = {
  args: {
    checkboxSize: "sm",
  },
};

export const Medium: Story = {
  args: {
    checkboxSize: "md",
  },
};

export const Large: Story = {
  args: {
    checkboxSize: "lg",
  },
};

export const Disabled: Story = {
  args: {
    disabled: true,
  },
};

export const DisabledChecked: Story = {
  args: {
    disabled: true,
    checked: true,
  },
};

function InteractiveCheckbox(props: { label: string; checkboxSize?: "sm" | "md" | "lg" }) {
  const [checked, setChecked] = createSignal(false);
  return (
    <label class="flex items-center gap-2 text-white cursor-pointer">
      <Checkbox
        checkboxSize={props.checkboxSize}
        checked={checked()}
        onChange={(e) => setChecked(e.currentTarget.checked)}
      />
      <span class="text-sm">{props.label}</span>
    </label>
  );
}

export const WithLabel: Story = {
  render: () => <InteractiveCheckbox label="Accept terms and conditions" />,
};

export const AllSizes: Story = {
  render: () => (
    <div class="flex flex-col gap-4">
      <InteractiveCheckbox checkboxSize="sm" label="Small checkbox" />
      <InteractiveCheckbox checkboxSize="md" label="Medium checkbox" />
      <InteractiveCheckbox checkboxSize="lg" label="Large checkbox" />
    </div>
  ),
};

export const AllStates: Story = {
  render: () => (
    <div class="flex flex-col gap-4">
      <label class="flex items-center gap-2 text-white">
        <Checkbox />
        <span class="text-sm">Unchecked</span>
      </label>
      <label class="flex items-center gap-2 text-white">
        <Checkbox checked />
        <span class="text-sm">Checked</span>
      </label>
      <label class="flex items-center gap-2 text-white opacity-50">
        <Checkbox disabled />
        <span class="text-sm">Disabled</span>
      </label>
      <label class="flex items-center gap-2 text-white opacity-50">
        <Checkbox disabled checked />
        <span class="text-sm">Disabled Checked</span>
      </label>
    </div>
  ),
};
