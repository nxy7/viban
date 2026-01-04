import { type JSX, splitProps } from "solid-js";

type CheckboxSize = "sm" | "md" | "lg";

interface CheckboxProps
  extends Omit<JSX.InputHTMLAttributes<HTMLInputElement>, "class" | "type"> {
  checkboxSize?: CheckboxSize;
}

const sizeClasses: Record<CheckboxSize, string> = {
  sm: "w-3.5 h-3.5",
  md: "w-4 h-4",
  lg: "w-5 h-5",
};

export default function Checkbox(props: CheckboxProps) {
  const [local, rest] = splitProps(props, ["checkboxSize"]);

  const size = local.checkboxSize ?? "md";

  const baseClasses =
    "text-brand-600 bg-gray-700 border-gray-600 rounded focus:ring-brand-500 focus:ring-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed";

  const classes = [baseClasses, sizeClasses[size]].join(" ");

  return <input {...rest} type="checkbox" class={classes} />;
}
