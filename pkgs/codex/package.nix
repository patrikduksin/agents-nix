{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  ripgrep,
}:
let
  sources = lib.importJSON ./sources.json;
  platform =
    sources.platforms.${stdenv.hostPlatform.system}
      or (throw "codex: no release binary for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "codex";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${sources.version}/codex-package-${platform.name}.tar.gz";
    inherit (platform) hash;
  };

  # The package archive is codex plus the sidecars it spawns from its own
  # directory (bin/codex-code-mode-host runs every tool call since 0.165), so
  # keep the tree whole. On Linux codex and the host are static (musl).
  preUnpack = "mkdir package && cd package";
  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/codex
    cp -r . $out/lib/codex
    makeWrapper $out/lib/codex/bin/codex $out/bin/codex \
      --argv0 codex \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME=$TMPDIR $out/bin/codex --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Codex, OpenAI's coding agent CLI (official release build)";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames sources.platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
