# monkmode — landing page

Static landing for the MonkMode macOS app. Vite + React + Tailwind. Phosphor
terminal theme matching the native app's retro CRT aesthetic.

## Dev

```bash
yarn
yarn dev
```

## Build

```bash
yarn build
```

Output lands in `dist/` and gets deployed as the GitHub Pages target for
`monkmode.app` (or whatever domain is configured).

## Structure

- `src/App.tsx` — layout shell, status bar, footer, CRT overlays
- `src/components/Hero.tsx` — ASCII `MONKMODE` wordmark, download button,
  GitHub release fetch with version fallback
- `src/components/Features.tsx` — terminal data-block feature grid
- `src/components/InstallSteps.tsx` — 3-step install rendered as shell prompts
- `src/components/CRTOverlay.tsx` — scanlines, vignette, subtle flicker

## Theming

CSS variables live in `src/index.css`. Tailwind semantic tokens map to them:
`phosphor` / `phosphor-dim` / `phosphor-muted` / `amber` / `danger` / `surface`.
Menlo is set as the default body font via `font-mono`.
