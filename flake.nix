{
  description = "T3 Code nightly, Claude Code and Codex from official release binaries, bumped hourly by CI; plus the Linux iOS cross tools Exact needs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      names = [ "t3code" "claude-code" "codex" "swift-bin" "xtool" "rcodesign" ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      callAll = callPackage: lib.genAttrs names (name: callPackage ./pkgs/${name}/package.nix { });
      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";
            }
          )
        );
    in
    {
      # The Exact iOS tools (swift-bin, xtool, rcodesign) are Linux-only: a Mac has Xcode.
      packages = forAllSystems (
        pkgs:
        lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform) (callAll pkgs.callPackage)
        // { default = self.packages.${pkgs.system}.t3code; }
      );

      # Replaces nixpkgs' t3code, claude-code and codex. claude-code is unfree:
      # the consuming nixpkgs needs allowUnfree (or a predicate allowing it).
      overlays.default = final: _prev: callAll final.callPackage;
    };
}
