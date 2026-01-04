import type { JSX } from "solid-js";

type ChipVariant = "purple" | "gray" | "blue" | "yellow" | "red" | "green";

interface ChipProps {
  variant?: ChipVariant;
  children: JSX.Element;
}

const variantClasses: Record<ChipVariant, string> = {
  purple: "bg-purple-500/20 text-purple-400",
  gray: "bg-gray-700/50 text-gray-400",
  blue: "bg-blue-500/20 text-blue-400",
  yellow: "bg-yellow-500/20 text-yellow-400",
  red: "bg-red-500/20 text-red-400",
  green: "bg-green-500/20 text-green-400",
};

export default function Chip(props: ChipProps) {
  const variant = props.variant ?? "gray";

  return (
    <span
      class={`text-xs px-1.5 py-0.5 rounded ${variantClasses[variant]}`}
    >
      {props.children}
    </span>
  );
}
