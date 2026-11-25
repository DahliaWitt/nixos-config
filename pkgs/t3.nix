# T3 Code server and CLI, from the prebuilt Linux release. nixpkgs' t3code
# builds from source and lags behind; the Mac app needs a matching version.
# Bump with pkgs/update.sh (also run by the scheduled update).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libsecret,
  vulkan-loader,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "t3";
  version = "0.1.12";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-m6PbRuNVT7mXD9Xt6egjwvbW9nY/QDQL1MjvawlQHFQ=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    libsecret
    # Voice transcription's GPU backend.
    vulkan-loader
  ];

  # The t3 executable carries its app payload inside the file; stripping
  # would destroy it.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    # Prebuilt musl variants of native modules; this is a glibc system.
    find node_modules -type d -name '*musl*' -prune -exec rm -rf {} +
    mkdir -p $out/lib/t3 $out/bin
    cp -r . $out/lib/t3
    makeWrapper $out/lib/t3/t3 $out/bin/t3
    runHook postInstall
  '';

  meta = {
    description = "T3 Code server and CLI";
    homepage = "https://t3.codes";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
