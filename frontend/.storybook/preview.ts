import type { Preview } from "storybook-solidjs-vite";
import "../src/app.css";

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    backgrounds: {
      default: "dark",
      values: [
        { name: "dark", value: "#1a1a2e" },
        { name: "gray", value: "#374151" },
        { name: "light", value: "#ffffff" },
      ],
    },
  },
};

export default preview;
