import { Show } from "solid-js";
import { useAuth } from "~/hooks/useAuth";
import Modal from "./ui/Modal";

function GitHubIcon(props: { class?: string }) {
  return (
    <svg
      class={props.class ?? "w-5 h-5"}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
    </svg>
  );
}

function Spinner() {
  return (
    <div class="animate-spin rounded-full h-5 w-5 border-2 border-brand-500 border-t-transparent" />
  );
}

export default function DeviceLoginModal() {
  const auth = useAuth();

  const flow = () => auth.deviceFlow();

  const handleOpenGitHub = () => {
    const f = flow();
    if (f) {
      window.open(f.verificationUri, "_blank");
    }
  };

  const copyCode = async () => {
    const f = flow();
    if (f) {
      await navigator.clipboard.writeText(f.userCode);
    }
  };

  return (
    <Modal
      isOpen={flow() !== null}
      onClose={() => auth.cancelLogin()}
      title="Sign in with GitHub"
    >
      <Show when={flow()}>
        {(flowData) => (
          <div class="space-y-6">
            <div class="text-center">
              <GitHubIcon class="w-12 h-12 mx-auto mb-4 text-gray-400" />
              <p class="text-gray-300 mb-2">
                Visit GitHub and enter this code:
              </p>
            </div>

            <div class="relative">
              <div class="bg-gray-800 border border-gray-700 rounded-lg py-4 px-6 text-center">
                <code class="text-2xl font-mono font-bold text-white tracking-widest">
                  {flowData().userCode}
                </code>
              </div>
              <button
                onClick={copyCode}
                class="absolute top-2 right-2 p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
                title="Copy code"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                  />
                </svg>
              </button>
            </div>

            <button
              onClick={handleOpenGitHub}
              class="w-full py-3 px-4 bg-gray-800 hover:bg-gray-700 text-white rounded-lg transition-colors flex items-center justify-center gap-2 border border-gray-700"
            >
              <GitHubIcon class="w-5 h-5" />
              Open {flowData().verificationUri.replace("https://", "")}
            </button>

            <div class="flex items-center justify-center gap-3 text-gray-400 text-sm">
              <Spinner />
              <span>Waiting for authorization...</span>
            </div>

            <button
              onClick={() => auth.cancelLogin()}
              class="w-full py-2 text-gray-400 hover:text-gray-200 text-sm transition-colors"
            >
              Cancel
            </button>
          </div>
        )}
      </Show>
    </Modal>
  );
}
