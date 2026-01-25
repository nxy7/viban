import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
import { resolve } from "path"
import tailwindcss from "tailwindcss"
import autoprefixer from "autoprefixer"

export default defineConfig(({ command }) => {
  const isDev = command === "serve"

  return {
    plugins: [vue()],

    publicDir: "static",

    build: {
      target: "es2020",
      outDir: "../priv/static/assets",
      emptyOutDir: true,
      sourcemap: isDev,
      manifest: true,
      rollupOptions: {
        input: {
          app: resolve(__dirname, "js/app.ts")
        },
        output: {
          entryFileNames: "[name].js",
          chunkFileNames: "[name]-[hash].js",
          assetFileNames: "[name][extname]"
        }
      }
    },

    css: {
      postcss: {
        plugins: [
          tailwindcss,
          autoprefixer
        ]
      }
    },

    server: {
      host: "localhost",
      port: 5173,
      strictPort: true,
      origin: "http://localhost:5173",
      cors: true
    },

    resolve: {
      alias: {
        "@": resolve(__dirname, "js"),
        vue: "vue/dist/vue.esm-bundler.js"
      }
    },

    optimizeDeps: {
      include: ["vue", "phoenix", "phoenix_html", "phoenix_live_view"]
    }
  }
})
