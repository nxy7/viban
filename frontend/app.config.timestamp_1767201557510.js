// app.config.ts
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "@solidjs/start/config";
import { loadEnv } from "vite";
var __dirname = dirname(fileURLToPath(import.meta.url));
var projectRoot = resolve(__dirname, "..");
var env = loadEnv("development", projectRoot, "");
var frontendPort = parseInt(env.FRONTEND_PORT || "3000", 10);
var caddyPort = parseInt(env.CADDY_PORT || "8000", 10);
var hmrPorts = {
  client: parseInt(env.FRONTEND_HMR_CLIENT_PORT || "3001", 10),
  server: parseInt(env.FRONTEND_HMR_SERVER_PORT || "3002", 10),
  "server-function": parseInt(
    env.FRONTEND_HMR_SERVER_FUNCTION_PORT || "3003",
    10,
  ),
  ssr: parseInt(env.FRONTEND_HMR_SSR_PORT || "3004", 10),
};
var app_config_default = defineConfig({
  ssr: false,
  vite: ({ router }) => ({
    resolve: {
      alias: {
        "~": "/src",
      },
    },
    server: {
      port: frontendPort,
      strictPort: true,
      hmr:
        router === "client"
          ? {
              port: hmrPorts[router],
              path: `/_hmr/${router}`,
              host: "localhost",
              clientPort: caddyPort,
              protocol: "wss",
            }
          : void 0,
    },
  }),
});
export { app_config_default as default };
