# agents-nix

Nix packages, built from official release binaries and bumped every hour:

| Package | Source | Channel |
|---|---|---|
| `t3code` | [pingdotgg/t3code](https://github.com/pingdotgg/t3code) release archives | nightly |
| `claude-code` | Anthropic's native build (`claude-code-releases` bucket) | latest |
| `codex` | [openai/codex](https://github.com/openai/codex) release binaries (static musl on Linux) | stable, no alphas |

Nothing is compiled: each package downloads a binary and, on Linux, points it
at the Nix glibc. nixpkgs ships these too, but days behind.

A GitHub Action checks for new releases every hour, pins them in
`pkgs/<name>/sources.json` (hashes come from the publishers' own checksums:
T3's `SHA256SUMS`, Claude's `manifest.json`, GitHub's asset digests), builds
each one, runs its `--version`, and commits. So a flake that uses this as an
input picks up the newest of all three on `nix flake update`.

```nix
inputs.agents-nix = {
  url = "github:patrikduksin/agents-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};

# then: nixpkgs.overlays = [ agents-nix.overlays.default ];  (replaces pkgs.t3code, pkgs.claude-code, pkgs.codex)
# or:   agents-nix.packages.${system}.{t3code,claude-code,codex}
```

`claude-code` is unfree, so the consuming nixpkgs needs `allowUnfree` (or a
predicate allowing it).

Run `./update.sh` (or `./update.sh codex`) to bump pins by hand.

## iOS cross tools for Exact (Linux)

What [Exact](https://github.com/expo/exact)'s README lists for building iPhone
apps on Linux, from the same official binaries. These are pinned by hand to the
versions Exact names, not bumped by CI:

| Package | Source | Version |
|---|---|---|
| `swift-bin` | swift.org's Ubuntu 24.04 toolchain, run in an FHS environment (SwiftPM compiles `Package.swift` for the host, so it needs glibc's headers under `/usr`) | 6.4.2 |
| `xtool` | [xtool-org/xtool](https://github.com/xtool-org/xtool) AppImage; `xtool sdk install --slim Xcode_27.1.xip` extracts the iOS SDK | 1.24.0 |
| `rcodesign` | [apple-codesign](https://github.com/indygreg/apple-platform-rs) static musl binary | 0.29.0 |

`swift-bin` is named so the overlay leaves nixpkgs' source-built `swift` alone.
LLVM 23 comes from nixpkgs (`llvmPackages_23.llvm`; set `EXACT_APPLE_LLVM_BIN`
to its `bin`), and Rust from nixpkgs' `rustup`. Executables built for the host
by `swift-bin` need nix-ld (or `swift-bin.fhs`) to run.

Self-updaters are off: Claude Code runs with `DISABLE_AUTOUPDATER=1`. Don't use
`t3 update` or `t3 service install` with this package: they install a second
copy under `~/.t3/runtime` and write their own systemd unit.
