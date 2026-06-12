+++
[implementer]
agent = "claude-code"
model = "claude-fable-5"

[review.design]
agent = "claude-code"
subagent = "adversarial-reviewer"
model = "claude-opus"

[review.result]
agent = "claude-code"
subagent = "adversarial-reviewer"
model = "claude-opus"
+++

# Experiment 1: The skeleton and the brand — one beautiful page

## Description

Stand up `website/` (Astro static + Bun + Tailwind v4), build the nutorch design
system from the logo, and ship ONE page — the landing page — beautiful in both
dark and light mode. Everything later (docs layout, content, ops reference,
search) builds on the tokens and layout primitives established here, so this
experiment is where the look is decided.

Local-only: no deployment, no domain, nothing outward-facing.

**Decisions, made here:**

1. **Scaffold, termsurf-shaped**: `website/` with Astro (`output: "static"`),
   Bun, Tailwind v4 via `@tailwindcss/vite`, TypeScript. No React — nothing on
   the landing page needs an island; the theme toggle is a few lines of vanilla
   inline JS. Versions: current latest (termsurf proved Astro 6 + Tailwind 4.2
   together; we take the same majors). `website/node_modules`, `website/dist`,
   `website/.astro` gitignored; `bun.lock` committed.
2. **The palette comes from the logo, measured not guessed**: a small script
   samples the dominant hexes from `nutorch-2d.png` (shell greens, flame orange)
   and those become the brand tokens — `--color-primary` (shell green),
   `--color-accent` (flame orange), plus neutral background/foreground/border
   ramps tuned per mode. Dark mode is NOT inverted-light: a deep neutral
   (slightly warm, near-black) background where the green and flame read as
   glow; light mode a warm off-white where they read as ink. All tokens are CSS
   variables consumed by Tailwind v4's `@theme`, so utilities like `bg-primary`
   work everywhere.
3. **Dark/light mechanism: system preference + a toggle.** Tokens swap on
   `:root[data-theme="dark"]`; a tiny inline `<head>` script (the no-flash
   pattern from radcn) reads `localStorage ?? prefers-color-scheme` and sets the
   attribute before first paint; a header button toggles and persists. Both
   modes are first-class (issue requirement), and the toggle also makes
   verifying both modes trivial.
4. **Typography**: Space Grotesk (headings) + JetBrains Mono (code) — the
   pairing already proven on termsurf; body text in a clean system/grotesk
   stack. Self-hosted via `@fontsource` packages rather than Google Fonts
   runtime requests (faster, no third-party call, works offline in local
   preview). Swappable in one place if the beauty pass wants different voices.
5. **Shiki dual themes: `vitesse-light` + `vitesse-dark`** — Vitesse is
   green-accented, harmonizing with the shell instead of fighting it
   (tokyo-night's blues would). Two distinct wirings, named explicitly
   (design-review catch — they do NOT share config): `markdown.shikiConfig`
   `themes: { light, dark }` covers fenced markdown blocks (arriving with
   Experiment 2's content collections), while Astro's `<Code>` component — which
   is ALL of this experiment's landing-page code — ignores that config and must
   be passed `themes={{ light: "vitesse-light", dark:
   "vitesse-dark" }}`
   explicitly (a thin local wrapper component bakes the props in so later pages
   can't forget). Dual-theme output is inline light colors plus
   `--shiki-dark`/`--shiki-dark-bg` variables on every span, so the token sheet
   includes the dark-mode glue — with `!important`, because the light colors are
   INLINE styles that an ordinary rule can never beat (second-pass review
   catch):
   `:root[data-theme="dark"] .astro-code, :root[data-theme="dark"]
   .astro-code span { color: var(--shiki-dark) !important; background-color:
   var(--shiki-dark-bg) !important; }`
   — without it, code never switches modes.
6. **Logo pipeline, ported from termsurf**: copy `nutorch-2d.png` and
   `nutorch-3d.png` out of `v1/raw-images/` (porting, not editing v1) into
   `website/raw-images/`; a `scripts/process-images.ts` (sharp for resizing,
   `png-to-ico` for the ICO container — sharp cannot encode ICO; the same
   pairing termsurf uses) emits favicon (32px ICO + PNG), header logo sizes
   (1x/2x), and the hero image — checked into `public/` so builds don't depend
   on rerunning it. The 2D mark is the header/favicon logo; **the 3D render is
   the hero** (it has depth and delight the flat mark lacks at large sizes —
   final call by eye in verification).
7. **The landing page** (the one page, structure top to bottom): header (logo +
   wordmark, Docs placeholder link, GitHub link, theme toggle); hero (3D shell,
   name, one-line pitch "GPU tensors for every shell", sub-line naming
   MPS/PyTorch/any-shell); the install block (the three brew commands,
   Shiki-highlighted, with a copy affordance); a "see it" section — bash
   pipeline and Nushell pipeline side by side, real output shown; three or four
   feature cards (GPU-only by design; any shell, handles on stdout; autograd +
   nn built in; PyTorch semantics); footer (logo, license, GitHub). All content
   real — the same examples the README already pledges.
8. **Layout primitives established for later experiments**: `Base.astro` (HTML
   shell, fonts, theme script, header/footer slots) and the token sheet —
   `DocPage.astro` and content collections are Experiment 2, not here.
9. **Root hygiene integration**: the standard gates don't know about bun; this
   experiment's verification defines the site gate as
   `bun install --frozen-lockfile && bun run build` exiting clean. (A root
   convenience for running it is future work; not wired into cargo.)

## Changes

1. **`website/`** (NEW): Astro project as described — `astro.config.mjs` (static
   output, shikiConfig dual Vitesse themes), `src/styles/global.css` (Tailwind
   v4 import + `@theme` tokens + mode swap), `src/layouts/Base.astro`,
   `src/components/{Header,Footer,ThemeToggle}.astro`, `src/pages/index.astro`
   (the landing page), `scripts/process-images.ts`, `raw-images/` (the two
   ported logos), `public/` (processed assets), `package.json` + `bun.lock`.
2. **`.gitignore`**: website build artifacts and node_modules.
3. **`v1/`**: untouched (images are COPIED out).
4. **No Rust changes.**

## Verification

1. **Build gate**:
   `cd website && bun install --frozen-lockfile && bun run build` exits 0 with
   no errors or warnings; `dist/index.html` exists. (`bun.lock` is generated by
   the first ordinary install during implementation and committed;
   `--frozen-lockfile` is the steady-state check thereafter.)
2. **Both modes render, asserted in the HTML/CSS**: the built page contains the
   theme-init script, the `data-theme` toggle button, both Vitesse theme color
   sets on Shiki blocks (dual-theme spans with `--shiki-dark` variables), token
   definitions for both modes in the built CSS, AND the dark-mode glue rule
   carrying `!important` (presence of the variables alone proves nothing — the
   glue is what makes them take effect; additionally verified by computed-style
   or screenshot in gate 5).
3. **Shiki proof**: the built landing page's `nu` and `bash` demo blocks contain
   real token spans (multiple distinct colors), not flat text.
4. **Assets**: favicon.ico + logo PNGs + hero image present in `dist/`;
   `<link rel="icon">` and OG/title meta present in `dist/index.html`.
5. **The beauty check (the point)**: `bun run preview`, screenshot the landing
   page in BOTH modes (headless Chromium via Playwright if available, else
   manual), and LOOK at them. The experimenter applies the issue's bar — a
   stranger gets it, wants it, installs in a minute — and records screenshots'
   assessment in the Result; the user is the final judge and may iterate in a
   follow-up experiment.
6. **Hygiene**: dprint clean on touched md/json (website code formatting is
   Prettier-by-default from the scaffold — recorded, not fought); `v1/`
   untouched; Rust suite untouched.

**Pass** = gates 1–4 objectively green and 5 recorded with screenshots or an
explicit note that visual judgment is deferred to the user. **Fail** = build
broken, single-mode-only rendering, or flat (unhighlighted) code blocks.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only),
verifying claims against the actual installed Astro/Shiki sources in the
termsurf role model. **First pass: CHANGES REQUIRED** — 1 Required: the design
claimed Astro's `<Code>` component shares `markdown.shikiConfig`; it does NOT
(it defaults to `github-dark`, `themes={}`, `defaultColor='light'` and builds
its own highlighter), and since the landing page is wall-to-wall `<Code>`, the
dual-mode requirement rode on a false premise. Absorbed: explicit
`themes={{ light, dark }}` via a thin wrapper component, plus the dark-mode CSS
glue for the `--shiki-dark`/`--shiki-dark-bg` span variables. Optional folded:
`png-to-ico` named (sharp cannot encode ICO). Nit folded: the
`--frozen-lockfile` chicken-and-egg note. **Second pass: CHANGES REQUIRED** — 1
Required: the glue lacked `!important`, which is mandatory because Shiki emits
the light colors as INLINE styles (verified in `@shikijs/core` source:
`tokenNode.properties.style` per span) that no ordinary rule can override — the
code would have stayed light in dark mode; gate 2 also asserted variable
presence only, which is true even when the glue is inert. Both fixed:
`!important` on both declarations; gate 2 requires the glue rule and defers
effect-proof to gate 5's computed-style/screenshot. The reviewer confirmed
`.astro-code` is the right selector (class rename in `@astrojs/markdown-remark`)
and `--shiki-` the right prefix (the `--astro-code-` prefix applies only to the
unrelated css-variables theme path). **Third pass: APPROVED** — both fixes
confirmed verbatim; one non-blocking observation (the span-level
`background-color` is redundant but harmless).

## Result

**Result:** Pass

The skeleton stands and the landing page is real in both modes.

- **Scaffold**: `website/` with Astro 6.4.6 (declared `^6.1`; static), Tailwind
  4.3 via `@tailwindcss/vite`, Bun (276 installs across 375 packages, `bun.lock`
  committed, `--frozen-lockfile` verified as the steady-state check); no React,
  no islands — the only client JS is the inline theme-init, the toggle, and the
  copy button. `.gitignore` covers `website/{node_modules,dist,.astro}`.
- **The palette was measured, as designed**: a sharp-based sampler bucketed the
  2D mark's opaque pixels — shell green `#60d060/#60c060` family, flame
  `#f06020/#f07020` family — yielding brand tokens `--shell: #5cc962`,
  `--flame: #f06820`, with per-mode primaries (light: green ink `#28933e` on
  warm off-white `#f7f6f1`; dark: green glow `#6fd877` on warm near-black
  `#0f130f`). Tokens live as raw CSS variables swapped on
  `:root[data-theme="dark"]`, consumed through Tailwind's `@theme inline` so
  `bg-primary`/`text-muted` etc. work everywhere.
- **Dark/light**: the no-flash init script (respects a pre-set `data-theme`
  attribute — which the screenshot harness then uses — else
  `localStorage ?? prefers-color-scheme`), header toggle with sun/moon
  persisting to localStorage. An accidental confirmation of the system-pref
  path: headless Chrome inherited macOS dark mode and the bare `/` rendered dark
  on its own.
- **Shiki**: the `CodeBlock.astro` wrapper bakes
  `themes={{ vitesse-light, vitesse-dark }}` into every block; built HTML
  carries 12 distinct `--shiki-dark` colors across 94 dual-theme spans; the
  `!important` glue rule is present in the built CSS (minified, space elided:
  `var(--shiki-dark)!important`) and PROVEN effective by the screenshots — code
  blocks visibly switch themes with the page.
- **Assets**: `process-images.ts` (sharp + png-to-ico) emitted favicon.ico,
  64/128/192 marks, hero 1x/2x from the 3D render, and a 1200×630 OG image
  (mark + wordmark + tagline on brand dark); favicon links + OG/twitter meta in
  the built head. Sources copied from `v1/raw-images/` — v1 untouched.
- **The landing page**, top to bottom: header (mark + two-tone wordmark — `nu`
  green, `torch` flame — Docs→GitHub placeholder, GitHub, toggle); hero (3D
  shell over a soft radial brand glow, "GPU tensors for every shell",
  Install/GitHub buttons); Three commands (the brew install block with a copy
  button); See it run (bash and nushell demos side by side + an autograd block);
  four feature cards; footer.
- **Verification gates**: build exits 0 (one recorded UPSTREAM warning: Node's
  DEP0205 from Astro's own loader — present for any Astro 6 project on this
  Node, not from our code); both token sets in built CSS; dual-theme spans +
  glue asserted; assets + meta asserted; screenshots of BOTH modes captured via
  headless Chrome (`logs/issue-0012/landing-{light,dark}.png`, regenerable:
  `sed` a `data-theme` attribute into a dist test copy and screenshot it) — both
  reviewed by eye: dark reads as glow on near-black, light as ink on warm
  off-white, hero glow lifts the shell in both. `bun install --frozen-lockfile`
  green; dprint clean on touched files; Rust tree untouched.

## Conclusion

The look is decided and the primitives are in place: brand tokens measured from
the logo, both modes first-class with proven code-theme switching, and a landing
page that pitches, installs, and demos in one screen-and-a-half. The user is the
final judge of beauty — screenshots are ready for review, and refinements can
ride Experiment 2, which should add the docs layout (`DocPage.astro` with
sidebar) and the markdown content collections that the Shiki markdown config is
already waiting for.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context), reviewing BEFORE
the result commit. **Verdict: APPROVED — no Required findings.** The reviewer
reproduced every load-bearing claim independently: frozen-lockfile install
green; build exits 0 with exactly the one recorded upstream DEP0205 warning; 12
distinct `--shiki-dark` colors across exactly 94 dual-theme spans; both token
sets and the minified `!important` glue in the built CSS; the measured palette
hexes present verbatim; the two screenshots confirmed as genuinely different
renders with code themes visibly switching; fonts fully self-hosted (no CDN
requests — the only external URLs are github.com anchors and the `og:image`
metadata); assets complete; `raw-images/` byte-identical to the `v1/` sources
with `v1/` clean; `.gitignore` effective; plan commit 9ded370 predating
implementation; the result uncommitted at review time. Two Nits folded before
commit: "Astro 6.1" corrected to the installed 6.4.6 (declared `^6.1`), and "276
packages" expanded to the installer's full "276 installs across 375 packages".
