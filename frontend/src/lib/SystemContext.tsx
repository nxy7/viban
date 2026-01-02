import {
  createContext,
  createSignal,
  onMount,
  useContext,
  type ParentComponent,
} from "solid-js";
import * as sdk from "~/lib/generated/ash";
import { type SystemTool, unwrap } from "~/lib/useKanban";

const EXECUTOR_PREFERENCE_KEY = "viban:preferredExecutor";

export interface ExecutorInfo {
  name: string;
  type: string;
  available: boolean;
  capabilities: string[];
}

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

    const storedPreference = localStorage.getItem(EXECUTOR_PREFERENCE_KEY);
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
    localStorage.setItem(EXECUTOR_PREFERENCE_KEY, type);
  };

  const fetchTools = async () => {
    setToolsLoading(true);
    setToolsError(null);
    try {
      const result = await sdk.list_tools({}).then(unwrap);
      setTools(result as SystemTool[]);
    } catch (err) {
      console.error("[SystemContext] Failed to fetch tools:", err);
      setToolsError(
        err instanceof Error ? err.message : "Failed to fetch tools",
      );
    } finally {
      setToolsLoading(false);
    }
  };

  const fetchExecutors = async () => {
    setExecutorsLoading(true);
    try {
      const result = await sdk.list_executors({});
      if (!result.success) {
        console.error(
          "[SystemContext] Failed to fetch executors:",
          result.errors,
        );
        return;
      }
      const execs = (result.data ?? []) as ExecutorInfo[];
      setExecutors(execs);

      const defaultExec = calculateDefaultExecutor(execs);
      if (defaultExec && !selectedExecutor()) {
        setSelectedExecutorState(defaultExec);
      }
    } catch (err) {
      console.error("[SystemContext] Failed to fetch executors:", err);
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
