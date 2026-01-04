import { type JSX, splitProps } from "solid-js";

type SelectVariant = "default" | "dark" | "minimal";
type SelectSize = "sm" | "md" | "lg";

interface SelectProps
  extends Omit<JSX.SelectHTMLAttributes<HTMLSelectElement>, "class"> {
  variant?: SelectVariant;
  selectSize?: SelectSize;
  fullWidth?: boolean;
}

const variantClasses: Record<SelectVariant, string> = {
  default: "bg-gray-800 border-gray-700",
  dark: "bg-gray-900 border-gray-700",
  minimal: "bg-transparent border-transparent hover:bg-gray-800",
};

const sizeClasses: Record<SelectSize, string> = {
  sm: "px-2 py-1 text-xs",
  md: "px-3 py-2 text-sm",
  lg: "px-4 py-3 text-base",
};

export default function Select(props: SelectProps) {
  const [local, rest] = splitProps(props, [
    "variant",
    "selectSize",
    "fullWidth",
    "children",
  ]);

  const variant = local.variant ?? "default";
  const size = local.selectSize ?? "md";

  const baseClasses =
    "border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent transition-colors disabled:opacity-50 disabled:cursor-not-allowed";

  const classes = [
    baseClasses,
    variantClasses[variant],
    sizeClasses[size],
    local.fullWidth ? "w-full" : "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <select {...rest} class={classes}>
      {local.children}
    </select>
  );
}
