{
  inputs,
  ...
} @args:
let
  inherit (args.config) flake;
in

{
  # Install to flake-default; weirdfi.sh is enabled based on the uppermost module.
  flake.modules.nixos."weirdfi.sh-webroot" = flake.lib.nixos.mkAspect (with flake.tags; [ flake-default ])
    ({
      lib,
      config,
      pkgs,
      ...
    }:

    let
      inherit (pkgs) stdenv;
      inherit (inputs) nix-time;

      inherit (pkgs.by.lib) replaceOptionalVars;

      domain = "weirdfi.sh";
    in
    {
      options.by.www.${domain} = {
        pages = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              title       = lib.mkOption { type = lib.types.str; };
              description = lib.mkOption { type = lib.types.str; };
              tags        = lib.mkOption { type = lib.types.listOf lib.types.str; };
              date        = lib.mkOption { type = lib.types.str; };
              slug        = lib.mkOption { type = lib.types.str; };
              permalink   = lib.mkOption { type = lib.types.nullOr lib.types.str; };
              src         = lib.mkOption { type = lib.types.package; };
            };
          });
        };
        templates = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
        };
        lib = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
        };
      };

      config.by.websites.sites.${domain}.web-server.webroot =
        let
          cfg = config.by.www.${domain};

          removeLeadingSlash = uri:
            lib.strings.substring 1 (builtins.stringLength uri) uri;

          files = builtins.map (page: {
            name = (removeLeadingSlash page.slug) + "index.html";
            path = page.src;
          }) cfg.pages;
          permalinks = builtins.map (page: {
            name = (removeLeadingSlash page.permalink) + "index.html";
            path = page.src;
          }) (builtins.filter (x: x.permalink != null) cfg.pages);
          resources = [
            {
              name = "style.css";
              path = (stdenv.mkDerivation {
                name = "compiled-styles";
                src = ./stylesheets;
                buildPhase = ''
                  cat *.css > ./output.css
                '';
                installPhase = ''
                  cp ./output.css $out
                '';
              });
            }
            {
              name = "rss.xml";
              path = (pkgs.replaceVars ./rss.xml {
                nix-rfc822 = nix-time.lib.RFC-822 "GMT" inputs.self.lastModified;
              });
            }
            {
              name = "marbled-healthy.png";
              path = ./resources/marbled-healthy.png;
            }
            {
              name = "under-construction.png";
              path = ./resources/under-construction.png;
            }
            {
              name = "fishtank";
              path = import _panels/fishc { inherit pkgs; };
            }
          ];
        in
        pkgs.linkFarm "webroot" (files ++ permalinks ++ resources);
    });
}
