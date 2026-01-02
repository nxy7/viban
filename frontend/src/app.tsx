import { MetaProvider, Title } from "@solidjs/meta";
import { Router } from "@solidjs/router";
import { FileRoutes } from "@solidjs/start/router";
import { Suspense } from "solid-js";
import NotificationContainer from "./components/ui/NotificationContainer";
import { AuthProvider } from "./lib/useAuth";
import "./app.css";

export default function App() {
  return (
    <Router
      root={(props) => (
        <MetaProvider>
          <Title>Viban</Title>
          <AuthProvider>
            <Suspense>{props.children}</Suspense>
            <NotificationContainer />
          </AuthProvider>
        </MetaProvider>
      )}
    >
      <FileRoutes />
    </Router>
  );
}
