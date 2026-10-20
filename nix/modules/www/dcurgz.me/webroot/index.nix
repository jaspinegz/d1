{
  inputs,
  ...
} @args:
let
  inherit (args.config) flake;
in

{
  flake.modules.nixos."dcurgz.me-index" = flake.lib.nixos.mkAspect (with flake.tags; [ flake-default ])
    ({
      lib,
      config,
      pkgs,
      ...
    }:

    let
      inherit (pkgs.by.lib) replaceOptionalVars;
      cfg = config.by.www."dcurgz.me";
      inherit (cfg) templates;
      lib' = cfg.lib;

      index = pkgs.writeText "index.7" (import ./_src/index.7.nix { inherit lib pkgs; });
    in
    {
      config.by.www."dcurgz.me".pages = [
        {
          title = "Dylan Jasper Curzon";
          description = "Site Index";
          date = "2026-10-20";
          slug = "/";
          permalink = null;
          src = lib.pipe index [
            (path: replaceOptionalVars path templates)
            (path: lib'.renderMdoc "index.html" path)
          ];
        }
      ];
    });
}
