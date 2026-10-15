{
  pkgs,
  stdenv,
  target ? "index.js",
  ...
}:
let
  name = "fishc";
  inherit (pkgs) lib;

  shaders = import ./shaders { inherit pkgs stdenv; };
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

  patchPhase = 
    let
      shaderReplacements = lib.mapAttrsToList (shaderName: shader:
        let
          vert = "${shader}/${shaderName}.vert";
          frag = "${shader}/${shaderName}.frag";
        in
        ''
          --replace-fail '@@vert:${shaderName}@@' "$(cat ${vert})" \
          --replace-fail '@@frag:${shaderName}@@' "$(cat ${frag})"
        '') shaders;
      shaderReplacementTexts = lib.strings.join " \\" shaderReplacements;
    in
    ''
      cp -rv $src intermediates
      FILES=$(find intermediates -name *.c)
      for f in $FILES; do
        substituteInPlace $f ${shaderReplacementTexts}
      done
    '';

  buildPhase = ''
    runHook preBuild
    mkdir target/

    emcc \
      -lGL -lglfw3 \
      -sWASM=1 \
      -sUSE_GLFW=3 \
      -sUSE_WEBGL2=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 \
      -sINITIAL_MEMORY=1073741824 \
      -sENVIRONMENT=web,worker -sEXIT_RUNTIME=1 \
      -std=gnu11 -O3 \
      work/fish.c \
      -o "target/${target}"
  '';

  installPhase = ''
    mkdir $out/
    cp -v target/* $out/
  '';
}
