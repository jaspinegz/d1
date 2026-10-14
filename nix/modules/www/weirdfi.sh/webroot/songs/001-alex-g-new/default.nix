{
  inputs,
  ...
} @args:
let
  inherit (args.config) flake;
in

{
  flake.modules.nixos."weirdfi.sh-songs-001-alexg-new" = flake.lib.nixos.mkAspect (with flake.tags; [ flake-default ])
    ({
      lib,
      config,
      pkgs,
      ...
    }:

    let
      inherit (pkgs.by.lib) replaceOptionalVars;
      cfg = config.by.www."weirdfi.sh";
      inherit (cfg) templates;
      lib' = cfg.lib;
    in
    {
      config.by.www."weirdfi.sh".pages = [
        {
          title = "Alex G - New";
          description = "A song about substance abuse.";
          date = "2026-10-14";
          slug = "/songs/001-alex-g-new/";
          permalink = null;
          src = lib.pipe ./default.7 [
            (path: replaceOptionalVars path templates)
            (path: lib'.renderMdoc "index.html" path)
          ];
        }
      ];
    });
}
