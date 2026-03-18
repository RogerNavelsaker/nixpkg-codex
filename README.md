# codex

Nix packaging for `@openai/codex` using Bun and `bun2nix`.

## Package

- Upstream package: `@openai/codex`
- Pinned version: `0.115.0`
- Installed binary: `codex`
- Upstream executable invoked by Bun: `codex`

## What this repo does

- Uses `bun.lock` and generated `bun.nix` as the dependency lock surface for Nix
- Builds an internal Bun application package with `bun2nix`
- Exposes only the canonical binary name `codex`
- Provides a GitHub Actions workflow that can sync the pinned npm version

## Files

- `flake.nix`: flake entrypoint
- `nix/package.nix`: Nix derivation
- `nix/package-manifest.json`: pinned package metadata and exposed binary name
- `scripts/sync-from-npm.ts`: updates pinned npm metadata without changing the canonical output binary

## Usage

```bash
nix build
./result/bin/codex --help
```
