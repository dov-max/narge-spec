# Cutline Website

This directory contains the Astro-based static site for Cutline, a cut path DNS resolver service.

## Building

```bash
npm install
npm run build
```

The build outputs to `../docs/` which is served by GitHub Pages.

## Development

```bash
npm run dev
```

Visit http://localhost:4321/narge-spec/ to preview locally.

## Structure

- `src/pages/` — All site pages
- `src/layouts/Layout.astro` — Main layout with navigation and footer
- `src/components/` — Reusable components (JoinCard, StatsDisplay, etc.)
- `public/` — Static assets (favicon, etc.)

## Deployment

The site is automatically deployed to GitHub Pages via `.github/workflows/deploy.yml` when changes are pushed to the `main` branch.

## License

Dedicated to the public domain under CC0 1.0.
