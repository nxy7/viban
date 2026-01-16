import {
  createContext,
  createSignal,
  onMount,
  type ParentComponent,
  useContext,
} from "solid-js";
import { type SystemTool, unwrap } from "~/hooks/useKanban";
import * as sdk from "~/lib/generated/ash";
import { createLogger } from "~/lib/logger";
import type { ExecutorInfo } from "~/lib/socket";
import { getStoredString, setStoredString } from "~/lib/storageUtils";

const log = createLogger("System");

const EXECUTOR_PREFERENCE_KEY = "viban:preferredExecutor";

export type { ExecutorInfo };

interface SystemContextValue {
  tools: () => SystemTool[];
  toolsLoading: () => boolean;
  toolsError: () => string | null;
  executors: () => ExecutorInfo[];
  executorsLoading: () => boolean;
  selectedExecutor: () => string | null;
  setSelectedExecutor: (type: string) => void;
  hasClaudeCode: () => boolean;
  refetchTools: () => Promise<void>;
  refetchExecutors: () => Promise<void>;
}

const SystemContext = createContext<SystemContextValue>();

export const SystemProvider: ParentComponent = (props) => {
  const [tools, setTools] = createSignal<SystemTool[]>([]);
  const [toolsLoading, setToolsLoading] = createSignal(true);
  const [toolsError, setToolsError] = createSignal<string | null>(null);

  const [executors, setExecutors] = createSignal<ExecutorInfo[]>([]);
  const [executorsLoading, setExecutorsLoading] = createSignal(true);
  const [selectedExecutor, setSelectedExecutorState] = createSignal<
    string | null
  >(null);

  const hasClaudeCode = () =>
    executors().some((e) => e.type === "claude_code" && e.available);

  const calculateDefaultExecutor = (execs: ExecutorInfo[]): string | null => {
    const available = execs.filter((e) => e.available);
    if (available.length === 0) return null;

    const storedPreference = getStoredString(EXECUTOR_PREFERENCE_KEY);
    if (storedPreference) {
      const preferred = available.find((e) => e.type === storedPreference);
      if (preferred) return preferred.type;
    }

    const claudeCode = available.find((e) => e.type === "claude_code");
    if (claudeCode) return claudeCode.type;

    return available[0].type;
  };

  const setSelectedExecutor = (type: string) => {
    setSelectedExecutorState(type);
    setStoredString(EXECUTOR_PREFERENCE_KEY, type);
  };

  const fetchTools = async () => {
    setToolsLoading(true);
    setToolsError(null);
    try {
      const result = await sdk.list_tools({}).then(unwrap);
      setTools((result as SystemTool[]) ?? []);
    } catch (err) {
      log.error("Failed to fetch tools", { error: err });
      setToolsError(
        err instanceof Error ? err.message : "Failed to fetch tools",
      );
      setTools([]);
    } finally {
      setToolsLoading(false);
    }
  };

  const fetchExecutors = async () => {
    setExecutorsLoading(true);
    try {
      const result = await sdk.list_executors({});
      if (!result.success) {
        log.error("Failed to fetch executors", { errors: result.errors });
        return;
      }
      const execs = (result.data ?? []) as ExecutorInfo[];
      setExecutors(execs);

      const defaultExec = calculateDefaultExecutor(execs);
      if (defaultExec && !selectedExecutor()) {
        setSelectedExecutorState(defaultExec);
      }
    } catch (err) {
      log.error("Failed to fetch executors", { error: err });
    } finally {
      setExecutorsLoading(false);
    }
  };

  onMount(() => {
    fetchTools();
    fetchExecutors();
  });

  const value: SystemContextValue = {
    tools,
    toolsLoading,
    toolsError,
    executors,
    executorsLoading,
    selectedExecutor,
    setSelectedExecutor,
    hasClaudeCode,
    refetchTools: fetchTools,
    refetchExecutors: fetchExecutors,
  };

  return (
    <SystemContext.Provider value={value}>
      {props.children}
    </SystemContext.Provider>
  );
};

export function useSystem(): SystemContextValue {
  const context = useContext(SystemContext);
  if (!context) {
    throw new Error("useSystem must be used within a SystemProvider");
  }
  return context;
}
