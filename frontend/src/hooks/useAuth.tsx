import {
  createContext,
  createSignal,
  onCleanup,
  onMount,
  type ParentComponent,
  useContext,
} from "solid-js";
import type { VCSProvider } from "~/lib/types/vcs";

export interface User {
  id: string;
  provider: VCSProvider;
  provider_login: string;
  name: string | null;
  email: string | null;
  avatar_url: string | null;
}

export interface DeviceFlowState {
  userCode: string;
  verificationUri: string;
  expiresAt: Date;
  interval: number;
}

interface AuthContextValue {
  user: () => User | null;
  isLoading: () => boolean;
  isAuthenticated: () => boolean;
  deviceFlow: () => DeviceFlowState | null;
  login: () => Promise<void>;
  cancelLogin: () => Promise<void>;
  logout: () => Promise<void>;
  refetch: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue>();

export const AuthProvider: ParentComponent = (props) => {
  const [user, setUser] = createSignal<User | null>(null);
  const [isLoading, setIsLoading] = createSignal(true);
  const [deviceFlow, setDeviceFlow] = createSignal<DeviceFlowState | null>(
    null
  );

  let pollTimeoutId: number | undefined;

  const fetchUser = async () => {
    try {
      const response = await fetch("/api/auth/me", {
        credentials: "include",
      });
      const data = await response.json();
      if (data.ok && data.user) {
        setUser(data.user);
      } else {
        setUser(null);
      }
    } catch (error) {
      console.error("Failed to fetch user:", error);
      setUser(null);
    } finally {
      setIsLoading(false);
    }
  };

  onMount(() => {
    fetchUser();
  });

  onCleanup(() => {
    if (pollTimeoutId) {
      clearTimeout(pollTimeoutId);
    }
  });

  const login = async () => {
    try {
      const response = await fetch("/api/auth/device/code", {
        method: "POST",
        credentials: "include",
      });
      const data = await response.json();

      if (data.ok) {
        setDeviceFlow({
          userCode: data.user_code,
          verificationUri: data.verification_uri,
          expiresAt: new Date(Date.now() + data.expires_in * 1000),
          interval: data.interval,
        });

        pollForToken(data.interval);
      } else {
        console.error("Failed to start device flow:", data.error);
      }
    } catch (error) {
      console.error("Failed to start device flow:", error);
    }
  };

  const pollForToken = (interval: number) => {
    const poll = async () => {
      const flow = deviceFlow();
      if (!flow) return;

      if (new Date() > flow.expiresAt) {
        setDeviceFlow(null);
        return;
      }

      try {
        const response = await fetch("/api/auth/device/poll", {
          method: "POST",
          credentials: "include",
        });
        const data = await response.json();

        if (data.status === "success") {
          setUser(data.user);
          setDeviceFlow(null);
        } else if (data.status === "pending") {
          pollTimeoutId = window.setTimeout(poll, interval * 1000);
        } else if (data.status === "slow_down") {
          pollTimeoutId = window.setTimeout(poll, (interval + 5) * 1000);
        } else if (data.status === "expired") {
          setDeviceFlow(null);
        } else if (data.status === "error") {
          console.error("Device flow error:", data.message);
          setDeviceFlow(null);
        }
      } catch (error) {
        console.error("Failed to poll for token:", error);
        pollTimeoutId = window.setTimeout(poll, interval * 1000);
      }
    };

    poll();
  };

  const cancelLogin = async () => {
    if (pollTimeoutId) {
      clearTimeout(pollTimeoutId);
      pollTimeoutId = undefined;
    }

    try {
      await fetch("/api/auth/device/cancel", {
        method: "POST",
        credentials: "include",
      });
    } catch (error) {
      console.error("Failed to cancel device flow:", error);
    }

    setDeviceFlow(null);
  };

  const logout = async () => {
    try {
      await fetch("/api/auth/logout", {
        method: "POST",
        credentials: "include",
      });
      setUser(null);
    } catch (error) {
      console.error("Failed to logout:", error);
    }
  };

  const value: AuthContextValue = {
    user,
    isLoading,
    isAuthenticated: () => user() !== null,
    deviceFlow,
    login,
    cancelLogin,
    logout,
    refetch: fetchUser,
  };

  return (
    <AuthContext.Provider value={value}>{props.children}</AuthContext.Provider>
  );
};

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
