{
  lib,
  stdenv,
  fetchurl,
}:
let
  sources = lib.importJSON ./sources.json;
  platform =
    sources.platforms.${stdenv.hostPlatform.system}
      or (throw "rcodesign: no release binary for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "rcodesign";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F${sources.version}/apple-codesign-${sources.version}-${platform.name}.tar.gz";
    inherit (platform) hash;
  };

  # Static (musl): nothing to patch.
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 rcodesign $out/bin/rcodesign
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = "$out/bin/rcodesign --version";

  meta = {
    description = "Sign and notarize Apple binaries from any OS (official release build)";
    homepage = "https://github.com/indygreg/apple-platform-rs";
    license = lib.licenses.mpl20;
    mainProgram = "rcodesign";
    platforms = builtins.attrNames sources.platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
