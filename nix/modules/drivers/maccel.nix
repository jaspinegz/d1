{
  inputs,
  config,
  ...
}:

let
  inherit (config) flake;
in
{
  flake.modules.nixos.drivers-maccel = flake.lib.nixos.mkAspect []
    ({
      lib,
      config,
      ...
    }:

    {
      imports = [
        inputs.maccel.nixosModules.default
      ];

      hardware.maccel = {
        enable = true;
        enableCli = true; # Optional: for parameter discovery
        parameters = {
          sensMultiplier = 1.0;
          mode = "natural";
          decayRate = 0.01;
          offset = 2.0;
          limit = 2.0;
        };
      };
    });
}
