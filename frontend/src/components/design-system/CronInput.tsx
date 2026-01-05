import cronstrue from "cronstrue";
import { createMemo, For, Show } from "solid-js";

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

function getNextRuns(expression: string, count: number = 3): Date[] {
  if (!expression.trim()) return [];

  try {
    const parts = expression.trim().split(/\s+/);
    if (parts.length < 5) return [];

    const [minute, hour, dayOfMonth, month, dayOfWeek] = parts;
    const now = new Date();
    const runs: Date[] = [];

    for (let i = 0; i < 365 && runs.length < count; i++) {
      const candidate = new Date(now.getTime() + i * 24 * 60 * 60 * 1000);

      if (!matchesCronField(month, candidate.getMonth() + 1)) continue;
      if (!matchesCronField(dayOfMonth, candidate.getDate())) continue;
      if (!matchesCronField(dayOfWeek, candidate.getDay())) continue;

      const hoursToCheck = expandCronField(hour, 0, 23);
      const minutesToCheck = expandCronField(minute, 0, 59);

      for (const h of hoursToCheck) {
        for (const m of minutesToCheck) {
          const runTime = new Date(candidate);
          runTime.setHours(h, m, 0, 0);

          if (runTime > now) {
            runs.push(runTime);
            if (runs.length >= count) break;
          }
        }
        if (runs.length >= count) break;
      }
    }

    return runs;
  } catch {
    return [];
  }
}

function matchesCronField(field: string, value: number): boolean {
  if (field === "*") return true;

  const values = expandCronField(field, 0, 59);
  return values.includes(value);
}

function expandCronField(field: string, min: number, max: number): number[] {
  if (field === "*") {
    return Array.from({ length: max - min + 1 }, (_, i) => min + i);
  }

  const result: number[] = [];

  for (const part of field.split(",")) {
    if (part.includes("/")) {
      const [range, stepStr] = part.split("/");
      const step = parseInt(stepStr, 10);
      const [start, end] =
        range === "*" ? [min, max] : range.split("-").map((n) => parseInt(n));

      for (let i = start; i <= (end ?? max); i += step) {
        if (i >= min && i <= max) result.push(i);
      }
    } else if (part.includes("-")) {
      const [start, end] = part.split("-").map((n) => parseInt(n));
      for (let i = start; i <= end; i++) {
        if (i >= min && i <= max) result.push(i);
      }
    } else {
      const num = parseInt(part);
      if (!isNaN(num) && num >= min && num <= max) {
        result.push(num);
      }
    }
  }

  return [...new Set(result)].sort((a, b) => a - b);
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

function parseCronParts(
  value: string,
): [string, string, string, string, string] {
  const parts = value.trim().split(/\s+/);
  return [
    parts[0] || "0",
    parts[1] || "0",
    parts[2] || "*",
    parts[3] || "*",
    parts[4] || "6",
  ];
}

export default function CronInput(props: CronInputProps) {
  const cronParts = createMemo(() => parseCronParts(props.value));
  const humanReadable = createMemo(() => parseCronExpression(props.value));
  const nextRuns = createMemo(() => getNextRuns(props.value));

  const isValid = createMemo(() => {
    if (!props.value.trim()) return true;
    return humanReadable() !== null;
  });

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
