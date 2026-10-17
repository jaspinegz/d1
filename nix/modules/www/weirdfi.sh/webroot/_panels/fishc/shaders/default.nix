{
  pkgs,
  lib ? pkgs.lib,
  stdenv ? pkgs.stdenv,
}:

let
  vert_main = "v_main";
  vert_spv  = "vert.spv";
  frag_main = "f_main";
  frag_spv  = "frag.spv";
  profile = "spirv_1_5";
  version = "300";

  STAGE_VERT = "vert";
  STAGE_FRAG = "frag";
  #STAGE_GEOM = "geom"; # not supported in WebGL 2 / GLES 3

  knownStages = {
    ${STAGE_VERT} = { stage = "vert"; entry = "v_main"; };
    ${STAGE_FRAG} = { stage = "frag"; entry = "f_main"; };
    #${STAGE_GEOM} = { stage = "geom"; entry = "g_main"; };
  };

  mkShader = name: src: stages: stdenv.mkDerivation {
    inherit name src;
    dontUnpack = true;
    nativeBuildInputs = with pkgs; [
      shader-slang
      spirv-cross
    ];
    buildPhase = ''
      runHook preBuild
    '' + (lib.concatMapStringsSep "\n" (stage:
      (let
        stageName = knownStages.${stage}.stage; 
        entry     = knownStages.${stage}.entry;
        spvOut    = "${stageName}.spv";
        glslOut   = "${name}.${stageName}";
      in ''
        slangc ${src} -entry ${entry} -profile ${profile} -o ${spvOut}
        spirv-cross ${spvOut} --es --version ${version} --stage ${stageName} --output ${glslOut}
      '')) stages);
    installPhase = ''
      mkdir $out
    '' + (lib.concatMapStringsSep "\n" (stage:
      "cp -v ${name}.${stage} $out"
    ) stages);
  };
in
{
  tank = rec {
    stages = [ STAGE_VERT STAGE_FRAG ];
    drv = mkShader "tank" ./tank.slang stages;
  };
  fish = rec {
    stages = [ STAGE_VERT STAGE_FRAG ];
    drv = mkShader "fish" ./fish.slang stages;
  };
  dither = rec {
    stages = [ STAGE_VERT STAGE_FRAG ];
    drv = mkShader "dither" ./dither.slang stages;
  };
}
