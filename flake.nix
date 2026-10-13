{
  description = "T3 Code nightly, pinned and bumped by CI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = builtins.attrNames (nixpkgs.lib.importJSON ./sources.json).platforms;
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        t3code = pkgs.callPackage ./package.nix { };
        default = t3code;
      });

      overlays.default = final: _prev: { t3code = final.callPackage ./package.nix { }; };
    };
}
