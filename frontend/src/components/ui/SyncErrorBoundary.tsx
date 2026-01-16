import {
  createEffect,
  createSignal,
  ErrorBoundary,
  onCleanup,
  onMount,
  type ParentComponent,
  Show,
} from "solid-js";

interface SyncErrorDisplayProps {
  error: Error;
  onRetry: () => void;
}

function isNetworkError(error: Error): boolean {
  const message = error.message.toLowerCase();
  return (
    message.includes("network") ||
    message.includes("fetch") ||
    message.includes("http") ||
    message.includes("goaway") ||
    message.includes("connection") ||
    message.includes("timeout") ||
    message.includes("aborted") ||
    message.includes("failed to fetch")
  );
}

function SyncErrorDisplay(props: SyncErrorDisplayProps) {
  const isNetwork = () => isNetworkError(props.error);

  return (
    <div class="min-h-screen bg-gray-950 flex items-center justify-center p-8">
      <div class="max-w-md w-full bg-gray-900/50 border border-red-500/30 rounded-xl p-8 text-center">
        <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-red-500/10 flex items-center justify-center">
          <svg
            class="w-8 h-8 text-red-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
        </div>

        <h2 class="text-xl font-semibold text-white mb-2">
          {isNetwork() ? "Connection Error" : "Something went wrong"}
        </h2>

        <p class="text-gray-400 mb-6">
          {isNetwork()
            ? "Unable to connect to the server. This might be a temporary network issue."
            : "An unexpected error occurred. Please try again."}
        </p>

        <div class="bg-gray-800/50 rounded-lg p-3 mb-6 text-left">
          <p class="text-xs text-gray-500 font-mono break-all">
            {props.error.message || "Unknown error"}
          </p>
        </div>

        <button
          onClick={props.onRetry}
          class="w-full px-4 py-3 bg-brand-600 hover:bg-brand-700 text-white rounded-lg transition-colors font-medium"
        >
          Retry
        </button>

        <p class="text-xs text-gray-500 mt-4">
          {isNetwork()
            ? "If the problem persists, check your network connection or try refreshing the page."
            : "If this keeps happening, please report the issue."}
        </p>
      </div>
    </div>
  );
}

const STALL_TIMEOUT_MS = 15000;
const HEALTH_CHECK_INTERVAL_MS = 30000;
const MAX_CONSECUTIVE_FAILURES = 3;

import type { JSX } from "solid-js";

function ConnectionStallDetector(props: { children: JSX.Element }) {
  const [isStalled, setIsStalled] = createSignal(false);
  const [connectionCheckPassed, setConnectionCheckPassed] = createSignal(false);
  const [consecutiveFailures, setConsecutiveFailures] = createSignal(0);

  const checkConnection = async (): Promise<boolean> => {
    try {
      const response = await fetch("/api/ping", { method: "GET" });
      return response.ok;
    } catch {
      return false;
    }
  };

  onMount(() => {
    let healthCheckInterval: ReturnType<typeof setInterval> | undefined;

    const initialCheck = async () => {
      const ok = await checkConnection();
      if (ok) {
        setConnectionCheckPassed(true);
        setConsecutiveFailures(0);
        startPeriodicHealthChecks();
      }
    };

    const startPeriodicHealthChecks = () => {
      healthCheckInterval = setInterval(async () => {
        const ok = await checkConnection();
        if (ok) {
          setConsecutiveFailures(0);
          setIsStalled(false);
        } else {
          const failures = consecutiveFailures() + 1;
          setConsecutiveFailures(failures);
          if (failures >= MAX_CONSECUTIVE_FAILURES) {
            setIsStalled(true);
          }
        }
      }, HEALTH_CHECK_INTERVAL_MS);
    };

    initialCheck();

    const timeoutId = setTimeout(() => {
      if (!connectionCheckPassed()) {
        setIsStalled(true);
      }
    }, STALL_TIMEOUT_MS);

    onCleanup(() => {
      clearTimeout(timeoutId);
      if (healthCheckInterval) {
        clearInterval(healthCheckInterval);
      }
    });
  });

  createEffect(() => {
    if (connectionCheckPassed()) {
      setIsStalled(false);
    }
  });

  return (
    <Show
      when={!isStalled()}
      fallback={
        <SyncErrorDisplay
          error={new Error("Connection timed out. The server may be unavailable.")}
          onRetry={() => window.location.reload()}
        />
      }
    >
      {props.children}
    </Show>
  );
}

export const SyncErrorBoundary: ParentComponent = (props) => {
  return (
    <ErrorBoundary
      fallback={(err, reset) => (
        <SyncErrorDisplay
          error={err instanceof Error ? err : new Error(String(err))}
          onRetry={() => {
            reset();
            window.location.reload();
          }}
        />
      )}
    >
      <ConnectionStallDetector>{props.children}</ConnectionStallDetector>
    </ErrorBoundary>
  );
};

export default SyncErrorBoundary;
