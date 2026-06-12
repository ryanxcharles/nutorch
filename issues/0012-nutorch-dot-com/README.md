+++
status = "closed"
opened = "2026-06-11"
closed = "2026-06-11"
+++

# Issue 12: nutorch.com — a beautiful documentation website

## Goal

A **beautiful**, complete documentation website for **nutorch.com**: the pitch,
the three-command install, and full documentation of everything nutorch does —
tensors and handles, the daemon, autograd, neural networks, the Nushell module,
and a reference for all 185 ops — built on the nutorch brand (the green nautilus
shell with the flame) as a static Astro site, **built and verified locally**.
Deployment (Cloudflare Pages + the nutorch.com domain) is a SEPARATE future
issue — this issue ends with a production-quality `dist/` and a local preview,
nothing outward-facing.

Beauty is a first-class requirement, not a nice-to-have. The bar is: a stranger
landing on nutorch.com immediately understands what nutorch is, wants it, and
can be running GPU pipelines in their shell within a minute.

Two hard requirements, stated up front:

- **Both dark mode and light mode are fully supported** — the whole site
  (layout, brand colors, logo variants if needed, and Shiki code themes) renders
  beautifully in each.
- **Tailwind CSS v4** is the styling system (via the Vite plugin, with brand
  tokens as CSS variables).

## Background

### The role model (researched 2026-06-11)

Three of Ryan's sites were studied; **termsurf** (`~/dev/termsurf/website/`) is
the explicit role model:

- **Astro 6, `output: "static"`** — pure static HTML/CSS to `dist/`, zero
  server, near-zero client JS.
- **Bun** as package manager and script runner.
- **Tailwind CSS 4** via the Vite plugin; custom design tokens as CSS variables
  (termsurf uses the Tokyo Night palette, light + dark via
  `prefers-color-scheme`).
- **Cloudflare Pages** deployment:
  `bun run build && wrangler pages deploy
  dist`. No adapter, no CI, no
  wrangler.toml.
- Custom layout components (`Base.astro` shell, `DocPage.astro` with sidebar),
  custom `.prose-*` styling, fonts via Google Fonts (Space Grotesk + JetBrains
  Mono), a bespoke icon pipeline (`raw-icons/*.png` → sharp → favicon + typed
  registry).

The other two were rejected as models and the reasons recorded: **keypears** is
a full-stack TanStack Start app on AWS ECS/Terraform (an application, not a docs
site — though its markdown-blog-with-TOML-frontmatter build script is a nice
pattern); **radcn** is server-rendered Remix 3 with code-first content (right
for a live component library, wrong for a static, SEO-friendly, markdown-centric
docs site).

### Deviations from termsurf (decided in research, confirmed by experiment)

1. **Markdown content collections, not hand-authored `.astro` pages.**
   termsurf's ~9 docs pages are hand-written HTML-in-Astro with no syntax
   highlighting. Nutorch's documentation surface is much larger and wall-to-wall
   code. Astro content collections give drop-a-file authoring, typed
   frontmatter, and built-in **Shiki** highlighting.
2. **Shiki highlights Nushell natively — verified.** Shiki bundles a full
   `nushell` TextMate grammar (alias `nu`); a real nutorch pipeline rendered
   with 12 distinct token colors. `bash`, `json`, `ruby`, `rust`, and `toml`
   grammars are bundled too. Markdown fences beat hand-rolled HTML on both
   quality and effort. Shiki also ships a `tokyo-night` theme, and Astro's
   `shikiConfig` supports dual light/dark themes.
3. **The ops reference is GENERATED, not hand-written.** The `nutorch-ops`
   OpSpec table is the single source of truth for 185 ops and already generates
   `nutorch.nu`; the same data (`torch ops --json`, or reading the crate at
   build time) generates the reference — name, signature, params, defaults,
   pipeline/argument forms. Hand-writing 185 pages is how docs rot.
4. **The cheap essentials termsurf skipped**: sitemap (`@astrojs/sitemap`), OG
   meta tags, and search (**Pagefind** — indexes `dist/` post-build, pure
   client-side, one script tag).
5. **Starlight consciously rejected**: it would supply sidebar/search/dark mode
   for free but fights custom design the whole way. The site owns its look,
   termsurf-style.

### The brand

The nutorch logo is a **green nautilus shell with an orange flame** — the
Nushell shell ignited by the PyTorch flame. Two source images exist in the
frozen v1 archive (copying out of `v1/` is porting, not editing):

- `v1/raw-images/nutorch-2d.png` — flat mark, 820×820 (header/footer logo,
  favicon, OG image base)
- `v1/raw-images/nutorch-3d.png` — glossy 3D render, 850×850 (hero candidate)

The site's palette derives from the logo: greens (shell) as the primary, orange
(flame) as the accent — resolved against light and dark backgrounds in the
design experiment. This intentionally diverges from termsurf's Tokyo Night
blues; nutorch has its own colors. (Shiki code themes must harmonize — to be
chosen by eye in the design experiment.)

## Architecture

```
nutorch/website/              ← lives in THIS repo (like termsurf)
├── src/
│   ├── pages/                # landing, docs routes
│   ├── content/docs/         # markdown content collections (the docs)
│   ├── layouts/  components/ # Base shell, DocPage w/ sidebar, header/footer
│   └── styles/               # Tailwind 4 + brand tokens as CSS variables
├── public/                   # processed logos, favicon, OG image
├── scripts/                  # ops-reference generator (reads ops table/JSON)
├── astro.config.mjs
└── package.json              # bun; deploy = build + wrangler pages deploy
```

- **In-repo** so docs ride the same commits and review gates as the code they
  describe, and the ops-reference generator can read the workspace directly.
  Hygiene gates extend naturally: `bun run build` clean for the site, plus a
  staleness check for generated content (the `nutorch.nu` include_str! trick).
- **Content plan** (mirroring what the README already covers, which is the first
  draft): landing page; Getting Started (brew install, first pipeline); The
  Daemon (lifecycle, TTL, status); Tensors & Handles (dual input pattern,
  free/census, import/export); Autograd; Neural Networks (modules, optimizers,
  training loops, safetensors); Nushell (the module, structured data); Ops
  Reference (generated); plus install-from-source.
- **Deployment-ready, not deployed**: static output (no Workers, no adapter),
  designed for Cloudflare Pages later — but this issue is local-only.
  Verification is `astro build` + `astro preview` (or serving `dist/`).

## Design Questions (settled per-experiment)

1. **The look**: palette derived from the logo's green/orange, typography, hero
   treatment (2D mark vs 3D render), and which Shiki light/dark theme pair
   harmonizes. Dark and light mode are both required (see Goal); the open
   question is only the mechanism — `prefers-color-scheme` alone
   (termsurf-style) or a user toggle on top. Beauty gets its own design pass,
   not a leftover.
2. **Ops reference shape**: one page per op vs grouped category pages; how much
   per-op prose the OpSpec table can supply vs needs adding; whether the
   generator runs as a build step or commits generated markdown (staleness check
   either way).
3. **Logo asset pipeline**: termsurf-style sharp script (favicon, sizes, OG
   image) from the 820px sources; whether a vector/SVG redraw is worth it
   (recorded follow-up if so).
4. **Versioned docs?** No — one version, tracking main (0.1.x); revisit when
   there are users on old versions.

## Experiments

- [Experiment 1: The skeleton and the brand — one beautiful page](01-skeleton-and-brand.md)
  — **Pass** (skeleton + measured brand tokens + landing page, both modes proven
  by screenshot; Shiki dual themes switching via the !important glue)
- [Experiment 2: The docs — content collections and the written pages](02-the-docs.md)
  — **Pass** (8 pages, collection-driven sidebar, markdown Shiki proven; the
  honesty checker caught a fictional verb; screenshots caught the
  details-element sidebar bug)
- [Experiment 3: The ops reference — generated from the table](03-ops-reference.md)
  — **Pass** (185 ops / 9 generated category pages; staleness gate bites; dprint
  fixed-point invariant proven on the first draft)
- [Experiment 4: Search, sitemap, and the finishing pass](04-search-and-polish.md)
  — **Pass** (Pagefind search proven by CDP-driven interaction in both modes;
  sitemap with the /docs duplicate filtered; link gate bites; on-brand 404)

## Conclusion

**The goal is met.** nutorch.com exists as a complete, beautiful, local-only
static site under `website/`: run `bun run build && bun run preview` and the
whole thing serves from `dist/` — 20 routes, both modes, zero runtime external
requests.

What the four experiments built, in order:

1. **The skeleton and the brand** (Exp 1): Astro 6 static + Bun + Tailwind v4;
   brand tokens MEASURED from the logo (shell green `#5cc962`, flame `#f06820`)
   with per-mode ramps; dark/light via a no-flash `data-theme` script + header
   toggle; Shiki dual Vitesse themes with the `!important` glue (two review
   catches: `<Code>` ignores `markdown.shikiConfig`, and inline styles demand
   `!important`); the logo pipeline (favicon, marks, hero, OG card); the landing
   page.
2. **The docs** (Exp 2): typed content collections, the collection-driven
   sidebar (sections + order from frontmatter), prose styling, prev/next, and 8
   written pages drafted from the README and verified against the real binaries
   — the honesty checker caught a fictional verb (`nn step`); the screenshot
   gate caught the closed-`<details>` sidebar bug; the result reviewer caught a
   wrong `arange` form.
3. **The ops reference** (Exp 3): 9 category pages GENERATED from
   `torch ops --json` + live `usage:` lines — 185 ops, byte-stable, with a
   staleness gate (`check:ops-ref`) and the dprint fixed-point rule (formatter
   disagreement = generator bug).
4. **Search and polish** (Exp 4): Pagefind (17 docs pages indexed, proven by
   CDP-driven interaction in both modes), sitemap with the `/docs/` alias
   filtered, robots.txt, OG url/type/site_name, an on-brand 404 ("unknown
   handle: 404://"), and the `check:links` gate.

All four issue design questions settled (look from the logo with a toggle;
category-grouped generated reference, committed + staleness-checked; sharp +
png-to-ico pipeline, SVG redraw recorded as follow-up if ever wanted; no
versioned docs). The site is kept honest by four executable gates —
`check:content`, `check:ops-ref`, `check:links`, and the build itself.

Out and waiting, as scoped: deployment (Cloudflare Pages + the nutorch.com
domain) is the next issue; blog/RSS and CI remain recorded follow-ups.

## Scope

In: the Astro site under `website/`; brand/design system from the logo; landing
page; the documentation sections above; the generated ops reference; search,
sitemap, OG tags; logo asset pipeline; a clean local build and preview.

Out (recorded): **Cloudflare Pages deployment and nutorch.com domain wiring —
the next issue** (user decision: this issue is local-only); blog/RSS
(keypears-style — possible follow-up); versioned docs; analytics; interactive
in-browser demos (no daemon in a browser); Starlight or any docs framework; CI
auto-deploy.
