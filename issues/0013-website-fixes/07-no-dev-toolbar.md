+++
[implementer]
agent = "claude-code"
model = "claude-fable-5"

[review]
waived = "user decision 2026-06-12: no adversarial review for issue 0013"
+++

# Experiment 7: No dev toolbar, ever

## Description

Punch-list micro-fix: the Astro Dev Toolbar (the floating debug menu at the
bottom of dev-server pages) is unwanted. Notably it is DEV-ONLY — it never ships
in built output, so site visitors could never see it; this kills it in
`astro dev` too.

## Changes

`website/astro.config.mjs`: `devToolbar: { enabled: false }`. (Project-level, so
it holds for any contributor — the alternative,
`astro preferences disable devToolbar`, is per-machine.)

## Verification

Dev server HTML contains zero `astro-dev-toolbar` elements (asserted via curl
against a running `astro dev`); production build unchanged and clean.

## Result

**Result:** Pass — toolbar element count 0 in dev HTML; build clean (20 pages).

## Conclusion

One config line; project-level so it never returns for anyone.
