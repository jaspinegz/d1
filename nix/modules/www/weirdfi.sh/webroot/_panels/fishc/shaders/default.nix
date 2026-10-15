{
  pkgs,
  stdenv,
}:

let
  vert_main = "v_main";
  vert_spv  = "vert.spv";
  frag_main = "f_main";
  frag_spv  = "frag.spv";
  profile = "spirv_1_5";

  mkShader = name: src: stdenv.mkDerivation {
    inherit name src;
    dontUnpack = true;
    nativeBuildInputs = with pkgs; [
      shader-slang
      spirv-cross
    ];
    buildPhase = ''
      runHook preBuild
      slangc ${src} -entry ${vert_main} -profile ${profile} -o ${vert_spv}
      slangc ${src} -entry ${frag_main} -profile ${profile} -o ${frag_spv}
      spirv-cross ${vert_spv} --es --version 300 --stage vert --output ${name}.vert
      spirv-cross ${frag_spv} --es --version 300 --stage frag --output ${name}.frag
    '';
    installPhase = ''
      mkdir $out/
      cp -v ${name}.vert $out/
      cp -v ${name}.frag $out/
    '';
  };
in
{
  tank = mkShader "tank" ./tank.slang;
}
