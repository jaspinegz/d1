{
  inputs,
  ...
} @args:
let
  inherit (args.config) flake;
in

{
  flake.modules.home-manager.way-displays = flake.lib.home-manager.mkAspect
    (with flake.tags; [ nixos-desktop ])
    ({
      lib,
      config,
      ...
    }:

    {
      services.way-displays = {
        enable = true;
        settings = {
          ORDER = [
            "HDMI-A-1"
            "DP-2"
          ];
          ARRANGE = "ROW";
          ALIGN = "TOP";
          SCALING = false;
          AUTO_SCALE = false;
          # All displays
          VRR_OFF = [ "!.*$" ];
          MODE = [
            {
              NAME_DESC = "HDMI-A-1";
              WIDTH = 2560;
              HEIGHT = 1440;
              HZ = 60; # TODO
            }
            {
              NAME_DESC = "DP-2";
              WIDTH = 2560;
              HEIGHT = 1440;
              HZ = 360;
            }
          ];
          TRANSFORM = [
            {
              NAME_DESC = "HDMI-A-1";
              TRANSFORM = "270";
            }
          ];
        };
      };
    });
}
