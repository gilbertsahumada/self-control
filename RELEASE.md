# Release Guide

This project ships two things:
- macOS app installer (`SelfControl-<version>.dmg`)
- download landing page (GitHub Pages)

## One-time setup

1. Go to `Settings > Pages` in GitHub.
2. Set **Build and deployment** to **GitHub Actions**.
3. Confirm Actions are enabled for the repository.

## Standard release flow

1. Make sure everything passes locally:

```bash
swift test
swift build -c release
cd web && yarn build
```

2. Commit and push your changes to `main`.

3. Create and push a release tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

4. Wait for the `Release` workflow to finish.
   - It builds the DMG using `scripts/build_dmg.sh`.
   - It creates a **draft** GitHub release with the `.dmg` attached.

5. Open `Releases` in GitHub and publish the draft.

## Landing page updates

- The download page is built from `web/` and deployed by the `Pages` workflow.
- It runs on pushes to `main` when web files change.
- Public URL:

```text
https://gilbertsahumada.github.io/self-control/
```

## Download link behavior

The web app reads the latest release dynamically from:

```text
https://api.github.com/repos/gilbertsahumada/self-control/releases/latest
```

It automatically picks the first asset ending in `.dmg`.

## Local DMG build (manual)

```bash
./scripts/build_dmg.sh
```

Output:
- `dist/SelfControl.app`
- `dist/SelfControl-1.0.0.dmg`
