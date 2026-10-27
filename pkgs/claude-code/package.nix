{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  bubblewrap,
  socat,
}:
let
  sources = lib.importJSON ./sources.json;
  platform =
    sources.platforms.${stdenv.hostPlatform.system}
      or (throw "claude-code: no release binary for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit (sources) version;

  src = fetchurl {
    url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${sources.version}/${platform.name}/claude";
    inherit (platform) hash;
  };

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  # A Bun executable with its JS payload appended: no strip, no RUNPATH
  # rewriting. It only needs glibc, which the Nix interpreter finds on its own.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/libexec/claude
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/libexec/claude
    ''}
    # Nix owns updates; bubblewrap and socat back Claude's sandbox on Linux.
    makeWrapper $out/libexec/claude $out/bin/claude \
      --argv0 claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 ${lib.optionalString stdenv.hostPlatform.isLinux "\\
      --prefix PATH : ${lib.makeBinPath [ bubblewrap socat ]}"}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME=$TMPDIR $out/bin/claude --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Claude Code, Anthropic's agentic coding CLI (official native build)";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
    platforms = builtins.attrNames sources.platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
