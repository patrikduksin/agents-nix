{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  sources = lib.importJSON ./sources.json;
  platform =
    sources.platforms.${stdenv.hostPlatform.system}
      or (throw "t3code: no release archive for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "t3code";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${sources.version}/t3-${sources.version}-${platform.name}.tar.gz";
    inherit (platform) hash;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  # libstdc++ and libatomic for the t3 binary and its native node modules.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  # The binary carries its JS payload after the ELF sections; stripping drops it.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/t3code $out/bin
    cp -r . $out/lib/t3code
    ln -s $out/lib/t3code/t3 $out/bin/t3
    runHook postInstall
  '';

  meta = {
    description = "T3 Code server and CLI (nightly)";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = builtins.attrNames sources.platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
