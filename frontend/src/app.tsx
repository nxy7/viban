import { MetaProvider, Title } from "@solidjs/meta";
import { Router } from "@solidjs/router";
import { FileRoutes } from "@solidjs/start/router";
import { Suspense } from "solid-js";
import DeviceLoginModal from "./components/DeviceLoginModal";
import NotificationContainer from "./components/ui/NotificationContainer";
import { AuthProvider } from "./hooks/useAuth";
import { EscapeStackProvider } from "./hooks/useEscapeStack";
import "./app.css";

export default function App() {
  return (
    <Router
      root={(props) => (
        <MetaProvider>
          <Title>Viban</Title>
          <EscapeStackProvider>
            <AuthProvider>
              <Suspense>{props.children}</Suspense>
              <NotificationContainer />
              <DeviceLoginModal />
            </AuthProvider>
          </EscapeStackProvider>
        </MetaProvider>
      )}
    >
      <FileRoutes />
    </Router>
  );
}
