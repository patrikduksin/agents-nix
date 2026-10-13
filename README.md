# t3code-nix

[T3 Code](https://github.com/pingdotgg/t3code) nightly as a Nix package, built
from the official release archives.

A GitHub Action checks for a new nightly every hour, pins it in `sources.json`
(hashes come from the release's `SHA256SUMS`), builds it, and commits. So a
flake that uses this as an input picks up the latest nightly on
`nix flake update`.

```nix
inputs.t3code = {
  url = "github:patrikduksin/t3code-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};

# then: t3code.packages.${system}.default, or nixpkgs.overlays = [ t3code.overlays.default ];
```

Run `./update.sh` to bump the pin by hand.

Don't use `t3 update` or `t3 service install` with this package: they install a
second copy under `~/.t3/runtime` and write their own systemd unit.
