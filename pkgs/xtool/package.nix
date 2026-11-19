{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:
let
  sources = lib.importJSON ./sources.json;
  platform =
    sources.platforms.${stdenv.hostPlatform.system}
      or (throw "xtool: no release binary for ${stdenv.hostPlatform.system}");
in
# The release is an AppImage; this runs it in an FHS environment, no FUSE.
appimageTools.wrapType2 {
  pname = "xtool";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/xtool-org/xtool/releases/download/${sources.version}/xtool-${platform.name}.AppImage";
    inherit (platform) hash;
  };

  meta = {
    description = "Cross-platform Xcode replacement: installs the Darwin SDK from an Xcode .xip on Linux (official release build)";
    homepage = "https://github.com/xtool-org/xtool";
    license = lib.licenses.mit;
    mainProgram = "xtool";
    platforms = builtins.attrNames sources.platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
