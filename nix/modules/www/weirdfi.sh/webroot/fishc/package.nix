{
  pkgs,
  stdenv,
  ...
}:
let
  name = "fishtank";
  inherit (pkgs.lib) getExe;
in
stdenv.mkDerivation rec {
  inherit name;
  src = ./.;
  nativeBuildInputs = with pkgs; [
    emscripten
  ];
  buildInputs = with pkgs; [
    glew
    glfw3
  ];
  #LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;

  buildPhase = ''
    mkdir target/
    runHook preBuild
    emcc \
      -lGL -lglfw3 \
      -sWASM=1 \
      -sUSE_GLFW=3 \
      -sUSE_WEBGL2=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 \
      -sINITIAL_MEMORY=1073741824 \
      -sENVIRONMENT=web,worker -sEXIT_RUNTIME=1 \
      -std=gnu11 -O3 \
      fish.c \
      -o target/index.html
  '';

  installPhase = ''
    mkdir -p $out
    cp target/* $out
  '';
}
