// @ts-check
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

export default defineConfig({
  output: "static",
  site: "https://nutorch.com",
  integrations: [
    sitemap({
      // /docs renders the same content as /docs/getting-started/ (which
      // carries the canonical); only the slug URL belongs in the sitemap.
      filter: (page) => page !== "https://nutorch.com/docs/",
    }),
  ],
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
