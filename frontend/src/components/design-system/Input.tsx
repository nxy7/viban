import { type JSX, splitProps } from "solid-js";

type InputVariant = "default" | "search" | "mono" | "dark" | "dark-mono";
type InputSize = "sm" | "md" | "lg";

interface InputProps extends Omit<JSX.InputHTMLAttributes<HTMLInputElement>, "class"> {
  variant?: InputVariant;
  inputSize?: InputSize;
  fullWidth?: boolean;
  hasIcon?: boolean;
}

const variantClasses: Record<InputVariant, string> = {
  default: "bg-gray-800 border-gray-700",
  search: "bg-gray-800 border-gray-700",
  mono: "bg-gray-800 border-gray-700 font-mono",
  dark: "bg-gray-900 border-gray-700",
  "dark-mono": "bg-gray-900 border-gray-700 font-mono",
};

const sizeClasses: Record<InputSize, string> = {
  sm: "px-3 py-1.5 text-sm",
  md: "px-3 py-2 text-sm",
  lg: "px-4 py-3 text-base",
};

export default function Input(props: InputProps) {
  const [local, rest] = splitProps(props, [
    "variant",
    "inputSize",
    "fullWidth",
    "hasIcon",
    "onKeyDown",
  ]);

  const handleKeyDown: JSX.EventHandler<HTMLInputElement, KeyboardEvent> = (e) => {
    if (e.key === "Escape") {
      e.currentTarget.blur();
    }
    if (typeof local.onKeyDown === "function") {
      local.onKeyDown(e);
    }
  };

  const baseClasses = "border rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent transition-colors disabled:opacity-50 disabled:cursor-not-allowed";
  const variant = local.variant ?? "default";
  const size = local.inputSize ?? "md";

  const classes = [
    baseClasses,
    variantClasses[variant],
    sizeClasses[size],
    local.fullWidth !== false ? "w-full" : "",
    local.hasIcon ? "pl-9" : "",
  ].filter(Boolean).join(" ");

  return (
    <input
      {...rest}
      class={classes}
      onKeyDown={handleKeyDown}
    />
  );
}
