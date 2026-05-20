# Homebrew packaging

Homebrew formula publishing for `omp` — **rolling**, updated on every push to `main`.

## End-user install

```sh
brew install PfisterFactor/tap/omp
```

Pulls the matching prebuilt binary from this repo's rolling `main-latest` GitHub Release — no source build, no toolchain required.

> **Rolling caveat:** because both the binary bytes and the formula's `sha256` pins are replaced on every commit, a stale local formula cache will fail with `SHA256 mismatch` on install. Run `brew update` first; on subsequent rolls `brew upgrade omp` picks up the latest build automatically.

## How it works

[`.github/workflows/homebrew.yml`](../../.github/workflows/homebrew.yml) runs on every push to `main` and on `workflow_dispatch`:

1. **`build` matrix** (4 jobs, fan-out): native Rust addon + Bun-compiled `omp` binary for darwin-{arm64,x64} and linux-{arm64,x64}. Each job smoke-runs `omp --version` and uploads its binary as an artifact.
2. **`publish`** (fan-in, one job):
   - Downloads all four binaries.
   - Upserts the rolling [`main-latest`](https://github.com/PfisterFactor/oh-my-pi/releases/tag/main-latest) GitHub Release. Only `omp-*` assets are scrubbed/re-uploaded, so it coexists with `rpm-fedora.yml`'s `*.rpm` assets on the same release.
   - Renders [`omp.rb.template`](./omp.rb.template) by substituting `{{VERSION}}` (from `packages/coding-agent/package.json`) and the four `{{URL_*}}` / `{{SHA_*}}` pairs (URLs point at `releases/download/main-latest/omp-*`; SHAs computed from the freshly built binaries).
   - Pushes the rendered `Formula/omp.rb` to [`PfisterFactor/homebrew-tap`](https://github.com/PfisterFactor/homebrew-tap) over SSH using the `HOMEBREW_TAP_DEPLOY_KEY` deploy key.

`brew update` picks up the new formula; `brew install`/`brew upgrade` re-downloads the binary because the `sha256` pin moved.

## Manual regeneration

If the workflow ever fails and you need to push a formula by hand, replicate the substitution locally against the assets already on `main-latest`:

```sh
BASE="https://github.com/PfisterFactor/oh-my-pi/releases/download/main-latest"
VERSION="$(jq -r .version packages/coding-agent/package.json)"

declare -A ASSETS=(
  [DARWIN_ARM64]=omp-darwin-arm64
  [DARWIN_X64]=omp-darwin-x64
  [LINUX_ARM64]=omp-linux-arm64
  [LINUX_X64]=omp-linux-x64
)
mkdir -p /tmp/omp-dl
ARGS=( -e "s|{{VERSION}}|${VERSION}|g" )
for key in "${!ASSETS[@]}"; do
  name="${ASSETS[$key]}"
  curl -fsSL "${BASE}/${name}" -o "/tmp/omp-dl/${name}"
  sha=$(sha256sum "/tmp/omp-dl/${name}" | awk '{print $1}')
  ARGS+=( -e "s|{{URL_${key}}}|${BASE}/${name}|g" )
  ARGS+=( -e "s|{{SHA_${key}}}|${sha}|g" )
done
sed "${ARGS[@]}" packaging/homebrew/omp.rb.template > /tmp/omp.rb
```

Then commit `/tmp/omp.rb` to `PfisterFactor/homebrew-tap` as `Formula/omp.rb`.

## Rotating the deploy key

The CI key lives as `HOMEBREW_TAP_DEPLOY_KEY` on this repo (private half) and as a write-enabled deploy key on the tap repo (public half). To rotate:

```sh
tmpdir=$(mktemp -d)
ssh-keygen -t ed25519 -N "" -C "ci@oh-my-pi" -f "$tmpdir/key"
gh repo deploy-key list --repo PfisterFactor/homebrew-tap          # find old key id
gh repo deploy-key delete --repo PfisterFactor/homebrew-tap <id>
gh repo deploy-key add "$tmpdir/key.pub" \
  --repo PfisterFactor/homebrew-tap --title "oh-my-pi CI (write)" --allow-write
gh secret set HOMEBREW_TAP_DEPLOY_KEY \
  --repo PfisterFactor/oh-my-pi --body "$(cat "$tmpdir/key")"
rm -rf "$tmpdir"
```

## Adding more formulas to the same tap

The tap repo can host arbitrary tools — one `Formula/<name>.rb` per tool. To package another project:

1. Copy `omp.rb.template` + the `homebrew.yml` workflow into the new project, swap the class name and asset names.
2. Reuse the same `HOMEBREW_TAP_DEPLOY_KEY` secret (or add it to the new repo from the existing key pair).
3. Write to `Formula/<new-name>.rb` from the new project's CI.

Users then run `brew install PfisterFactor/tap/<new-name>`.
