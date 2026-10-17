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
  mkCLiteral = drv: pkgs.runCommand "mk-c-literal" { } ''
    cp -v "${drv}" "$out"
    sed -i 's/"/\\"/g'  "$out"
    sed -i 's/^/"/g'    "$out"
    sed -i 's/$/\\n"/g' "$out"
  '';
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

        #let
        #  vert = "${shader}/${shaderName}.vert";
        #  frag = "${shader}/${shaderName}.frag";
        #  vert_syntax = mkCLiteral vert;
        #  frag_syntax = mkCLiteral frag;
        #in
        #''--replace-fail '@@vert:${shaderName}@@' "$(cat ${vert_syntax})" \
        #  --replace-fail '@@frag:${shaderName}@@' "$(cat ${frag_syntax})" \
        #'') shaders;
  patchPhase = 
    let
      shaderReplacements = lib.concatMapAttrsStringSep "\n" (shaderName: shader: 
        lib.concatMapStringsSep "\n" (stage:
          (let
            syntax = mkCLiteral "${shader.drv}/${shaderName}.${stage}";
          in ''--replace-fail '@@${stage}:${shaderName}@@' "$(cat ${syntax})" \'')
        ) shader.stages
      ) shaders;
    in
    ''
      cp -rv "$src" intermediates
      FILES=$(find intermediates -name *.c)
      for f in $FILES; do
        substituteInPlace $f ${shaderReplacements}

      done
    '';

  buildPhase = ''
    runHook preBuild
    mkdir target/

    emcc \
      -lGL -lglfw3 -lm \
      -sWASM=1 \
      -sUSE_GLFW=3 \
      -sUSE_WEBGL2=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 \
      -sINITIAL_MEMORY=1073741824 \
      -sENVIRONMENT=web,worker -sEXIT_RUNTIME=1 \
      -std=gnu11 -O3 \
      intermediates/fish.c \
      -o "target/${target}"
  '';

  installPhase = ''
    mkdir "$out"
    cp -v target/* "$out"
  '';
}
