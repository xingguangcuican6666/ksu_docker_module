import { defineConfig } from "vite";
import { resolve } from "node:path";

export default defineConfig({
  root: resolve("src"),
  base: "./",
  publicDir: false,
  build: {
    emptyOutDir: true,
    outDir: resolve("webroot"),
    target: "es2020",
    chunkSizeWarningLimit: 900,
  },
});
