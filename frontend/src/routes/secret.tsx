import { createMemo, createSignal, Show } from "solid-js";
import { useLiveQuery } from "@tanstack/solid-db";
import { eq, and } from "@tanstack/db";
import { syncActorStatesCollection } from "~/lib/generated/sync/collections";
import * as sdk from "~/lib/generated/ash";
import { unwrap } from "~/hooks/useKanban";

export default function SecretPage() {
  const actorStatesQuery = useLiveQuery((q) =>
    q
      .from({ actors: syncActorStatesCollection })
      .where(({ actors }) =>
        and(
          eq(actors.actor_type, "Elixir.Viban.StateServer.DemoAgent"),
          eq(actors.actor_id, "demo-agent"),
        ),
      )
      .select(({ actors }) => ({
        id: actors.id,
        actor_type: actors.actor_type,
        actor_id: actors.actor_id,
        state: actors.state,
        status: actors.status,
        message: actors.message,
        version: actors.version,
        updated_at: actors.updated_at,
      })),
  );

  const demoAgent = createMemo(() => {
    const data = actorStatesQuery.data;
    if (!data || data.length === 0) return undefined;
    return data[0];
  });

  const [localText, setLocalText] = createSignal("");
  const [isSaving, setIsSaving] = createSignal(false);

  const agentText = createMemo(() => {
    const agent = demoAgent();
    if (!agent?.state) return "";
    const state = agent.state as Record<string, unknown>;
    return (state.text as string) ?? "";
  });

  const handleSave = async () => {
    setIsSaving(true);
    await sdk.set_demo_text({ input: { text: localText() } }).then(unwrap);
    setIsSaving(false);
  };

  return (
    <main class="min-h-screen bg-gray-950 text-white p-8">
      <div class="max-w-2xl mx-auto">
        <h1 class="text-3xl font-bold text-brand-500 mb-2">Secret Page</h1>
        <p class="text-gray-400 mb-8">
          StateServer Demo - Real-time sync via Electric SQL
        </p>

        <div class="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-6">
          {/* Live State Display */}
          <div>
            <h2 class="text-lg font-semibold text-white mb-2">
              Live Agent State
            </h2>
            <Show
              when={demoAgent()}
              fallback={
                <p class="text-gray-500 italic">Loading agent state...</p>
              }
            >
              <div class="space-y-2">
                <div class="flex items-center gap-2">
                  <span class="text-gray-400">Status:</span>
                  <span
                    class={`px-2 py-0.5 rounded text-sm ${
                      demoAgent()?.status === "ok"
                        ? "bg-green-500/20 text-green-400"
                        : demoAgent()?.status === "error"
                          ? "bg-red-500/20 text-red-400"
                          : "bg-yellow-500/20 text-yellow-400"
                    }`}
                  >
                    {demoAgent()?.status}
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-gray-400">Text:</span>
                  <span class="text-white font-mono bg-gray-800 px-2 py-1 rounded">
                    {agentText() || "(empty)"}
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-gray-400">Version:</span>
                  <span class="text-gray-300">{demoAgent()?.version}</span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-gray-400">Updated:</span>
                  <span class="text-gray-300">
                    {demoAgent()?.updated_at
                      ? new Date(demoAgent()!.updated_at).toLocaleTimeString()
                      : "-"}
                  </span>
                </div>
              </div>
            </Show>
          </div>

          {/* Edit Form */}
          <div class="border-t border-gray-800 pt-6">
            <h2 class="text-lg font-semibold text-white mb-2">
              Update Agent Text
            </h2>
            <div class="flex gap-3">
              <input
                type="text"
                value={localText()}
                onInput={(e) => setLocalText(e.currentTarget.value)}
                placeholder="Enter new text..."
                class="flex-1 px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <button
                onClick={handleSave}
                disabled={isSaving() || !localText().trim()}
                class="px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:bg-gray-700 disabled:cursor-not-allowed text-white rounded-lg transition-colors"
              >
                {isSaving() ? "Saving..." : "Save"}
              </button>
            </div>
            <p class="text-gray-500 text-sm mt-2">
              Type something and click Save. The Live Agent State above will
              update in real-time via Electric SQL sync.
            </p>
          </div>

          {/* Raw State */}
          <div class="border-t border-gray-800 pt-6">
            <h2 class="text-lg font-semibold text-white mb-2">
              Raw State JSON
            </h2>
            <pre class="bg-gray-800 p-4 rounded-lg text-sm text-gray-300 overflow-auto">
              {JSON.stringify(
                demoAgent(),
                (_, v) => (typeof v === "bigint" ? v.toString() : v),
                2,
              )}
            </pre>
          </div>
        </div>

        <p class="text-gray-600 text-center mt-8 text-sm">
          Open this page in multiple tabs to see real-time sync in action!
        </p>
      </div>
    </main>
  );
}
