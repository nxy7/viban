import { type JSX, splitProps } from "solid-js";

type TextareaVariant = "default" | "mono" | "dark" | "dark-mono";
type TextareaSize = "sm" | "md" | "lg";

interface TextareaProps extends Omit<JSX.TextareaHTMLAttributes<HTMLTextAreaElement>, "class"> {
  variant?: TextareaVariant;
  textareaSize?: TextareaSize;
  fullWidth?: boolean;
  resizable?: boolean;
}

const variantClasses: Record<TextareaVariant, string> = {
  default: "bg-gray-800 border-gray-700",
  mono: "bg-gray-800 border-gray-700 font-mono",
  dark: "bg-gray-900 border-gray-700",
  "dark-mono": "bg-gray-900 border-gray-700 font-mono",
};

const sizeClasses: Record<TextareaSize, string> = {
  sm: "px-3 py-1.5 text-sm",
  md: "px-3 py-2 text-sm",
  lg: "px-4 py-3 text-base",
};

export default function Textarea(props: TextareaProps) {
  const [local, rest] = splitProps(props, [
    "variant",
    "textareaSize",
    "fullWidth",
    "resizable",
    "onKeyDown",
  ]);

  const handleKeyDown: JSX.EventHandler<HTMLTextAreaElement, KeyboardEvent> = (e) => {
    if (e.key === "Escape") {
      e.currentTarget.blur();
    }
    if (typeof local.onKeyDown === "function") {
      local.onKeyDown(e);
    }
  };

  const baseClasses = "border rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent transition-colors disabled:opacity-50 disabled:cursor-not-allowed";
  const variant = local.variant ?? "default";
  const size = local.textareaSize ?? "md";

  const classes = [
    baseClasses,
    variantClasses[variant],
    sizeClasses[size],
    local.fullWidth !== false ? "w-full" : "",
    local.resizable === false ? "resize-none" : "",
  ].filter(Boolean).join(" ");

  return (
    <textarea
      {...rest}
      class={classes}
      onKeyDown={handleKeyDown}
    />
  );
}
