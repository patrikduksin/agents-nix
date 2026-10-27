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

  # autoPatchelf sets the interpreter and RUNPATH in one patchelf call, which
  # (patchelf 0.19) leaves t3 with overlapping LOAD segments: ld.so segfaults
  # before main. Patching RUNPATH first, then the interpreter, keeps it valid,
  # so t3 is patched by hand and autoPatchelf only does the native modules.
  dontAutoPatchelf = true;
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    autoPatchelf $out/lib/t3code/node_modules $out/lib/t3code/resource-monitor
    patchelf --set-rpath ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]} $out/lib/t3code/t3
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/lib/t3code/t3
  '';

  # Fail the build, not the machine running it, when the binary can't start.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/t3 --version
    runHook postInstallCheck
  '';

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
