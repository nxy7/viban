import { createSignal, Show } from "solid-js";
import { Button, Input } from "~/components/design-system";
import type { Column } from "~/hooks/useKanban";
import { unwrap } from "~/hooks/useKanban";
import * as sdk from "~/lib/generated/ash";
import { InfoBanner } from "../ui/ErrorBanner";
import { InfoIcon } from "../ui/Icons";
import Toggle from "../ui/Toggle";

const SUCCESS_FEEDBACK_DURATION_MS = 2000;

interface ConcurrencySettingsProps {
  column: Column;
}

export default function ConcurrencySettings(props: ConcurrencySettingsProps) {
  const [enabled, setEnabled] = createSignal(
    props.column.settings?.max_concurrent_tasks != null,
  );
  const [limit, setLimit] = createSignal(
    props.column.settings?.max_concurrent_tasks || 3,
  );
  const [isSaving, setIsSaving] = createSignal(false);
  const [saveSuccess, setSaveSuccess] = createSignal(false);

  const handleToggle = async (newEnabled: boolean) => {
    setEnabled(newEnabled);
    if (!newEnabled) {
      setIsSaving(true);
      try {
        await sdk
          .update_column_settings({
            identity: props.column.id,
            input: { settings: { max_concurrent_tasks: null } },
          })
          .then(unwrap);
        setSaveSuccess(true);
        setTimeout(() => setSaveSuccess(false), SUCCESS_FEEDBACK_DURATION_MS);
      } finally {
        setIsSaving(false);
      }
    }
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await sdk
        .update_column_settings({
          identity: props.column.id,
          input: {
            settings: { max_concurrent_tasks: enabled() ? limit() : null },
          },
        })
        .then(unwrap);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), SUCCESS_FEEDBACK_DURATION_MS);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h4 class="text-sm font-medium text-gray-200">
            Limit Concurrent Tasks
          </h4>
          <p class="text-xs text-gray-500 mt-0.5">
            Control how many tasks can run at once
          </p>
        </div>
        <Toggle
          checked={enabled()}
          onChange={handleToggle}
          disabled={isSaving()}
        />
      </div>

      <Show when={enabled()}>
        <div class="space-y-4 pl-3 border-l-2 border-brand-500/30">
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Maximum Concurrent Tasks
            </label>
            <div class="flex items-center gap-3">
              <Input
                type="number"
                min={1}
                max={100}
                value={limit()}
                onInput={(e) => {
                  const val = parseInt(e.currentTarget.value, 10);
                  if (!Number.isNaN(val) && val >= 1) setLimit(val);
                }}
                variant="dark"
                inputSize="sm"
                fullWidth={false}
                style={{ width: "5rem", "text-align": "center" }}
              />
              <span class="text-sm text-gray-400">tasks at once</span>
            </div>
          </div>

          <Button
            onClick={handleSave}
            disabled={isSaving()}
            loading={isSaving()}
            fullWidth
            buttonSize="sm"
          >
            <Show when={!isSaving()}>
              {saveSuccess() ? "Saved!" : "Save Limit"}
            </Show>
          </Button>
        </div>
      </Show>

      <InfoBanner>
        <InfoIcon class="w-4 h-4 inline mr-1" />
        When the limit is reached, new tasks will queue and start automatically
        when a slot becomes available.
      </InfoBanner>
    </div>
  );
}
