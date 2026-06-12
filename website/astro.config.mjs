// @ts-check
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

export default defineConfig({
  output: "static",
  site: "https://nutorch.com",
  vite: {
    plugins: [tailwindcss()],
  },
  markdown: {
    // Fenced markdown blocks (content collections, experiment 2+). The
    // <Code> component does NOT read this config — the CodeBlock wrapper
    // passes the same themes explicitly.
    shikiConfig: {
      themes: { light: "vitesse-light", dark: "vitesse-dark" },
    },
  },
});
