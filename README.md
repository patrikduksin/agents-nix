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

Self-updaters are off: Claude Code runs with `DISABLE_AUTOUPDATER=1`. Don't use
`t3 update` or `t3 service install` with this package: they install a second
copy under `~/.t3/runtime` and write their own systemd unit.
