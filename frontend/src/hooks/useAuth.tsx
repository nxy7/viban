import {
  createContext,
  createSignal,
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

interface AuthContextValue {
  user: () => User | null;
  isLoading: () => boolean;
  isAuthenticated: () => boolean;
  login: (provider?: VCSProvider) => void;
  logout: () => Promise<void>;
  refetch: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue>();

export const AuthProvider: ParentComponent = (props) => {
  const [user, setUser] = createSignal<User | null>(null);
  const [isLoading, setIsLoading] = createSignal(true);

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

    // Check URL for auth callback result
    const params = new URLSearchParams(window.location.search);
    const authResult = params.get("auth");
    if (authResult) {
      // Clean up URL
      const url = new URL(window.location.href);
      url.searchParams.delete("auth");
      window.history.replaceState({}, "", url.pathname);

      if (authResult === "success") {
        // Refetch user after successful auth
        fetchUser();
      }
    }
  });

  const login = (provider: VCSProvider = "github") => {
    // Redirect to OAuth provider
    window.location.href = `/auth/${provider}`;
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
    login,
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
