{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  runCommand,
  binutils,
  curl,
  gcc,
  glibc,
  libedit,
  libuuid,
  libxml2_13,
  ncurses,
  python312,
  sqlite,
  zlib,
  z3,
}:
let
  sources = lib.importJSON ./sources.json;
  platform =
    sources.platforms.${stdenv.hostPlatform.system}
      or (throw "swift-bin: no release toolchain for ${stdenv.hostPlatform.system}");
  inherit (sources) version;

  # swift.org's Ubuntu toolchain, unpacked as it is.
  toolchain = stdenv.mkDerivation {
    pname = "swift-bin-toolchain";
    inherit version;
    src = fetchurl {
      url = "https://download.swift.org/swift-${version}-release/${
        lib.replaceStrings [ "." ] [ "" ] platform.name
      }/swift-${version}-RELEASE/swift-${version}-RELEASE-${platform.name}.tar.gz";
      inherit (platform) hash;
    };
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;
    installPhase = ''
      mkdir -p $out
      cp -r usr/* $out/
    '';
  };

  # Ubuntu's libedit2 has soname libedit.so.2; nixpkgs' same library is .so.0.
  # The loader's cache indexes sonames, so the FHS puts /usr/lib on
  # LD_LIBRARY_PATH, where it finds this link by its file name.
  ubuntuSonames = runCommand "swift-bin-ubuntu-sonames" { } ''
    mkdir -p $out/lib
    ln -s ${libedit}/lib/libedit.so.0 $out/lib/libedit.so.2
  '';

  # The toolchain expects an Ubuntu root: glibc's headers and crt files under
  # /usr for the host side (SwiftPM compiles and runs Package.swift manifests
  # natively, even when it builds for iOS), and Ubuntu's sonames.
  fhs = buildFHSEnv {
    name = "swift-bin-fhs";
    targetPkgs = _: [
      binutils
      curl
      gcc
      gcc.cc
      gcc.cc.lib
      glibc
      glibc.dev
      libedit
      ubuntuSonames
      libuuid
      libxml2_13
      ncurses
      python312
      sqlite
      zlib
      z3
    ];
    profile = ''
      export LD_LIBRARY_PATH=/usr/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    '';
    runScript = "";
  };
in
# Every toolchain command, each run inside that root. Named swift-bin so the
# overlay leaves nixpkgs' source-built swift alone.
runCommand "swift-bin-${version}"
  {
    passthru = { inherit toolchain fhs; };
    meta = {
      description = "Swift toolchain from swift.org's Ubuntu release, in an FHS environment (official release build)";
      homepage = "https://www.swift.org";
      license = lib.licenses.asl20;
      mainProgram = "swift";
      platforms = builtins.attrNames sources.platforms;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
  ''
    mkdir -p $out/bin
    for tool in ${toolchain}/bin/*; do
      name=$(basename "$tool")
      printf '#!${stdenv.shell}\nexec ${fhs}/bin/swift-bin-fhs %s "$@"\n' "$tool" > "$out/bin/$name"
      chmod +x "$out/bin/$name"
    done
    ln -s ${toolchain}/lib $out/lib
    ln -s ${toolchain}/include $out/include
    ln -s ${toolchain}/share $out/share

    # Check: a host executable compiles, links against glibc and runs.
    tmp=$(mktemp -d)
    echo 'print("ok")' > $tmp/main.swift
    HOME=$tmp $out/bin/swiftc $tmp/main.swift -o $tmp/main -module-cache-path $tmp/cache
    [ "$(${fhs}/bin/swift-bin-fhs $tmp/main)" = ok ]
  ''
