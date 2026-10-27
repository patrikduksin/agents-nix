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
    url = "https://github.com/openai/codex/releases/download/rust-v${sources.version}/codex-${platform.name}.tar.gz";
    inherit (platform) hash;
  };

  # The archive holds a single binary; on Linux it is static (musl).
  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 codex-${platform.name} $out/libexec/codex
    makeWrapper $out/libexec/codex $out/bin/codex \
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
