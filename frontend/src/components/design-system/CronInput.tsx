import cronstrue from "cronstrue";
import { createMemo, For, Show } from "solid-js";
import { getNextRuns, parseCronParts } from "~/lib/cronUtils";

interface CronFieldConfig {
  locked?: boolean;
  lockedValue?: string;
}

interface CronInputProps {
  value: string;
  onChange: (value: string) => void;
  error?: string | null;
  minute?: CronFieldConfig;
  hour?: CronFieldConfig;
  dayOfMonth?: CronFieldConfig;
  month?: CronFieldConfig;
  dayOfWeek?: CronFieldConfig;
}

const DAYS_OF_WEEK = [
  { value: "*", label: "Every day" },
  { value: "1-5", label: "Weekdays" },
  { value: "0,6", label: "Weekends" },
  { value: "1", label: "Monday" },
  { value: "2", label: "Tuesday" },
  { value: "3", label: "Wednesday" },
  { value: "4", label: "Thursday" },
  { value: "5", label: "Friday" },
  { value: "6", label: "Saturday" },
  { value: "0", label: "Sunday" },
];

const HOURS = [
  { value: "*", label: "Every hour" },
  ...Array.from({ length: 24 }, (_, i) => ({
    value: String(i),
    label: `${i.toString().padStart(2, "0")}:00`,
  })),
];

const DAYS_OF_MONTH = [
  { value: "*", label: "Every day" },
  { value: "1", label: "1st" },
  { value: "15", label: "15th" },
  { value: "1,15", label: "1st & 15th" },
  ...Array.from({ length: 31 }, (_, i) => ({
    value: String(i + 1),
    label: `${i + 1}`,
  })).slice(1),
];

const MONTHS = [
  { value: "*", label: "Every month" },
  { value: "1", label: "January" },
  { value: "2", label: "February" },
  { value: "3", label: "March" },
  { value: "4", label: "April" },
  { value: "5", label: "May" },
  { value: "6", label: "June" },
  { value: "7", label: "July" },
  { value: "8", label: "August" },
  { value: "9", label: "September" },
  { value: "10", label: "October" },
  { value: "11", label: "November" },
  { value: "12", label: "December" },
];

function parseCronExpression(expression: string): string | null {
  if (!expression.trim()) return null;

  try {
    return cronstrue.toString(expression, {
      throwExceptionOnParseError: true,
      use24HourTimeFormat: true,
    });
  } catch {
    return null;
  }
}

function formatDate(date: Date): string {
  const options: Intl.DateTimeFormatOptions = {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  };
  return date.toLocaleString(undefined, options);
}

export default function CronInput(props: CronInputProps) {
  const cronParts = createMemo(() => parseCronParts(props.value));
  const humanReadable = createMemo(() => parseCronExpression(props.value));
  const nextRuns = createMemo(() => getNextRuns(props.value));

  const updateField = (index: number, newValue: string) => {
    const parts = [...cronParts()];
    parts[index] = newValue;
    props.onChange(parts.join(" "));
  };

  const minuteLocked = props.minute?.locked ?? true;
  const minuteValue = props.minute?.lockedValue ?? "0";

  const selectClass = (locked: boolean) =>
    `px-2 py-1.5 bg-gray-800 border border-gray-700 rounded text-sm text-white
     focus:outline-none focus:ring-1 focus:ring-brand-500 focus:border-brand-500
     ${locked ? "opacity-50 cursor-not-allowed" : "cursor-pointer"}`;

  return (
    <div class="space-y-3">
      <div class="flex flex-wrap gap-2 items-center">
        <div class="flex flex-col gap-1">
          <label class="text-xs text-gray-500">Hour</label>
          <select
            class={selectClass(props.hour?.locked ?? false)}
            value={cronParts()[1]}
            onChange={(e) => updateField(1, e.currentTarget.value)}
            disabled={props.hour?.locked}
          >
            <For each={HOURS}>
              {(opt) => <option value={opt.value}>{opt.label}</option>}
            </For>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs text-gray-500">Day of Week</label>
          <select
            class={selectClass(props.dayOfWeek?.locked ?? false)}
            value={cronParts()[4]}
            onChange={(e) => updateField(4, e.currentTarget.value)}
            disabled={props.dayOfWeek?.locked}
          >
            <For each={DAYS_OF_WEEK}>
              {(opt) => <option value={opt.value}>{opt.label}</option>}
            </For>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs text-gray-500">Day of Month</label>
          <select
            class={selectClass(props.dayOfMonth?.locked ?? false)}
            value={cronParts()[2]}
            onChange={(e) => updateField(2, e.currentTarget.value)}
            disabled={props.dayOfMonth?.locked}
          >
            <For each={DAYS_OF_MONTH}>
              {(opt) => <option value={opt.value}>{opt.label}</option>}
            </For>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs text-gray-500">Month</label>
          <select
            class={selectClass(props.month?.locked ?? false)}
            value={cronParts()[3]}
            onChange={(e) => updateField(3, e.currentTarget.value)}
            disabled={props.month?.locked}
          >
            <For each={MONTHS}>
              {(opt) => <option value={opt.value}>{opt.label}</option>}
            </For>
          </select>
        </div>
      </div>

      <Show when={minuteLocked}>
        <div class="text-xs text-gray-500">
          Minute locked to {minuteValue} (runs at most once per hour)
        </div>
      </Show>

      <div class="flex items-center gap-2 text-xs text-gray-500">
        <span>Raw:</span>
        <code class="px-2 py-1 bg-gray-800 rounded font-mono text-gray-400">
          {props.value || "0 0 * * 6"}
        </code>
      </div>

      <Show when={props.error}>
        <div class="text-red-400 text-xs">{props.error}</div>
      </Show>

      <Show when={props.value.trim()}>
        <Show
          when={humanReadable()}
          fallback={
            <div class="text-red-400 text-xs">Invalid cron expression</div>
          }
        >
          <div class="text-brand-400 text-sm">{humanReadable()}</div>
        </Show>

        <Show when={nextRuns().length > 0}>
          <div class="text-xs text-gray-500">
            <span class="font-medium">Next runs:</span>
            <ul class="mt-1 space-y-0.5">
              <For each={nextRuns()}>
                {(date) => <li class="text-gray-400">{formatDate(date)}</li>}
              </For>
            </ul>
          </div>
        </Show>
      </Show>
    </div>
  );
}
