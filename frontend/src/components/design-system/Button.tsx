import { createMemo, type JSX, Show, splitProps } from "solid-js";

type ButtonVariant = "primary" | "secondary" | "danger" | "ghost" | "icon" | "badge";
type ButtonSize = "sm" | "md" | "lg";

interface ButtonProps extends Omit<JSX.ButtonHTMLAttributes<HTMLButtonElement>, "class"> {
  variant?: ButtonVariant;
  buttonSize?: ButtonSize;
  fullWidth?: boolean;
  loading?: boolean;
  children?: JSX.Element;
  class?: string;
}

const variantClasses: Record<ButtonVariant, string> = {
  primary: "bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 text-white",
  secondary: "bg-gray-800 hover:bg-gray-700 text-gray-300",
  danger: "bg-red-600 hover:bg-red-700 disabled:bg-red-800 text-white",
  ghost: "bg-transparent hover:bg-gray-800 text-gray-400 hover:text-white",
  icon: "w-6 h-6 flex items-center justify-center text-gray-400 hover:text-brand-400 active:text-brand-500",
  badge: "text-xs w-5 h-5 rounded border flex items-center justify-center",
};

const sizeClasses: Record<ButtonSize, string> = {
  sm: "px-3 py-1.5 text-sm",
  md: "px-4 py-2 text-sm",
  lg: "px-6 py-3 text-base",
};

export default function Button(props: ButtonProps) {
  const [local, rest] = splitProps(props, [
    "variant",
    "buttonSize",
    "fullWidth",
    "loading",
    "children",
    "disabled",
    "class",
  ]);

  const variant = () => local.variant ?? "primary";
  const size = () => local.buttonSize ?? "md";
  const isCompact = () => variant() === "icon" || variant() === "badge";

  const classes = createMemo(() => {
    const baseClasses = isCompact()
      ? "transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
      : "rounded-lg transition-colors disabled:cursor-not-allowed font-medium flex items-center justify-center gap-2";

    return [
      baseClasses,
      variantClasses[variant()],
      !isCompact() ? sizeClasses[size()] : "",
      local.fullWidth ? "w-full" : "",
      local.class,
    ].filter(Boolean).join(" ");
  });

  return (
    <button
      {...rest}
      disabled={local.disabled || local.loading}
      class={classes()}
    >
      <Show when={local.loading}>
        <svg
          class="w-4 h-4 animate-spin"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle
            class="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            stroke-width="4"
          />
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          />
        </svg>
      </Show>
      {local.children}
    </button>
  );
}
