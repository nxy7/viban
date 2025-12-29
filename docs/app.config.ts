import { defineConfig } from "@solidjs/start/config";

export default defineConfig({
  server: {
    preset: "static",
    prerender: {
      crawlLinks: true,
      routes: [
        "/",
        "/features",
        "/contact",
        "/docs",
        "/docs/getting-started",
        "/docs/installation",
        "/docs/boards-and-tasks",
        "/docs/ai-agents",
        "/docs/hooks",
        "/docs/task-refinement",
        "/docs/git-integration",
        "/docs/custom-hooks",
        "/docs/api",
        "/docs/mcp",
        "/404",
      ],
    },
  },
});
