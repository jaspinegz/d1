{
  inputs,
  ...
} @args:
let
  inherit (args.config) flake;
in

{
  flake.modules.nixos."weirdfi.sh-songs" = flake.lib.nixos.mkAspect (with flake.tags; [ flake-default ])
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
      songs =
        let
          songs = lib.pipe cfg.pages [
            # only show songs
            (builtins.filter (post: pkgs.by.lib.strings.startsWith "/songs/" post.slug))
            # don't show the index page
            (builtins.filter (post: post.slug != "/songs/"))
            # sort by date
            (builtins.sort (a: b: a.date < b.date))
            # render as mdoc list
            (builtins.map (post:
              ''
                .It
                .Lk ${post.slug} ${post.title}
                (${post.date})
              ''))
            # 
            (lib.strings.join "\n")
          ];
        in ''
        .Bl
        ${songs}
        .El
      '';
    in
    {
      config.by.www."weirdfi.sh".pages = [
        rec {
          title = "Song Index";
          description = "A bunch of thoughts about my favourite songs.";
          date = "2026-10-14";
          slug = "/songs/";
          permalink = null;
          src = lib.pipe ./default.7 [
            (path: replaceOptionalVars path templates)
            (path: replaceOptionalVars path { inherit title description songs; })
            (path: lib'.renderMdoc "index.html" path)
          ];
        }
      ];
    });
}
