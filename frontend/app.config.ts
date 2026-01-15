import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "@solidjs/start/config";
import { loadEnv } from "vite";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");

const env = loadEnv("development", projectRoot, "");
const frontendPort = parseInt(env.FRONTEND_PORT || "7778", 10);

const hmrPorts: Record<string, number> = {
  client: parseInt(env.FRONTEND_HMR_CLIENT_PORT || "7779", 10),
  server: parseInt(env.FRONTEND_HMR_SERVER_PORT || "7780", 10),
  "server-function": parseInt(
    env.FRONTEND_HMR_SERVER_FUNCTION_PORT || "7781",
    10,
  ),
  ssr: parseInt(env.FRONTEND_HMR_SSR_PORT || "7782", 10),
};

export default defineConfig({
  ssr: false,
  vite: ({ router }: { router: string }) => ({
    resolve: {
      alias: {
        "~": "/src",
      },
    },
    server: {
      host: "0.0.0.0",
      port: frontendPort,
      strictPort: true,
      hmr:
        router === "client"
          ? {
              port: hmrPorts[router],
              host: "localhost",
              clientPort: hmrPorts[router],
              protocol: "ws",
            }
          : undefined,
    },
  }),
});
