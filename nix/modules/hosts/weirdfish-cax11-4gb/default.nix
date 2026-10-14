{
  inputs,
  lib,
  globals,
  prebuiltPackages,
  ...
} @args:

let
  inherit (args.config) flake;
  inherit (args.config.by) keys;

  genAttrs' = names: f: lib.listToAttrs (map f names);
  stripLocation = cfg: lib.removeSuffix "/" cfg.nginx.location;
in
{
  flake.nixosConfigurations.weirdfish-cax11-4gb = flake.lib.mkNixOS rec {
    system = "aarch64-linux";
    specialArgs = {
      pkgs = prebuiltPackages.${system};
    };
    modules = with flake.modules; [
      (with flake.tags; flake.lib.use [
        flake-default
        nixos-base
      ])
      nixos.weirdfish-cax11-4gb
      nixos.weirdfish-cax11-4gb-hardware
      nixos.weirdfish-cax11-4gb-disk
      nixos.authorized-keys
      nixos."dcurgz.me"
      nixos."weirdfi.sh"
      {
        by.presets.authorized-keys.groups = [
          {
            users = [ "root" "jaspine" "builder" "git" ];
            keys = keys.ssh.groups.privileged.paths;
          }
        ];
      }
      nixos.linux-builder
    ];
  };

  flake.modules.nixos.weirdfish-cax11-4gb = flake.lib.nixos.mkAspect (with flake.tags; [ hosts ])
    ({
      lib,
      pkgs,
      config,
      ...
    }:

    {
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
      boot.loader.efi.canTouchEfiVariables = true;

      time.timeZone = "Europe/London";

      i18n.defaultLocale = "en_GB.UTF-8";
      console.keyMap = "uk";

      security.sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };

      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
      };

      services.fail2ban.enable = true;

      networking = {
        hostName = "weirdfish-cax11-4gb";
        enableIPv6 = true;
        firewall = {
          enable = true;
          allowedTCPPorts = [ 22 ];
        };
      };

      users.users.jaspine = {
        isNormalUser = true;
        group = "jaspine";
        extraGroups = [ "wheel" ];
        home = "/home/jaspine";
      };
      users.groups.jaspine = { };
      nix.settings.trusted-users = [ "jaspine" ];

      systemd.tmpfiles.rules = [
        "Z /data/git 775 root wheel"
      ];

      services.gitDaemon = {
        enable = true;
        basePath = "/data/git";
        port = config.by.portmap.internal.git-server;
      };

      # Git user currently has RO access to all Git repositories.
      # This is provided by the world-readable /data/git permissions.
      # wheel has write access to the directory, so jaspine can make changes.
      users.users.git = {
        isSystemUser = true;
        group = "git";
      };
      users.groups.git = { };

      # The cgit user is a privileged account that the cgit service runs as.
      users.users.cgit = {
        isSystemUser = true;
        extraGroups = [ "git" ];
        group = "cgit";
      };
      users.groups.cgit = { };

      services.fcgiwrap.instances."cgit-weirdfish" = {
        process = {
          user = "cgit";
          group = "cgit";
        };
        socket = {
          user = "nginx";
          group = "nginx";
        };
      };

      services.nginx =
        let
          cgit = pkgs.cgit.overrideAttrs (_:prev: {
            postPatch = prev.postPatch + ''
              ${pkgs.git}/bin/git apply ${./cgit-about-subtree.patch}
            '';
          });
          git-root = "/data/git/";
          about-filter = pkgs.writeText "filter.c" ''
            #include <err.h>
            #include <fnmatch.h>
            #include <stdio.h>
            #include <stdlib.h>
            #include <unistd.h>
          
            int main(int argc, char *argv[]) {
              if (argc < 1) return 1;
              if (!fnmatch("README.[1-9]", argv[1], 0) ||
                  !fnmatch("*README.[1-9]", argv[1], 0)) {
                execlp("${pkgs.mandoc}/bin/mandoc", "mandoc", "-T", "html", (char*)NULL);
                err(127, "mandoc");
              } else if (!fnmatch("README.md", argv[1], 0) || 
                  !fnmatch("*README.md", argv[1], 0)) {
                execlp("${pkgs.md4c}/bin/md2html", "md2html", "--github", (char*)NULL);
                err(127, "md2html");
              } else {
                //TODO this is broken i guess
                int c;
                while((c = getchar()) != EOF) {
                  putchar(c);
                }
                return 0;
              }
              return 1;
            }
          '';
          about-filter' = pkgs.stdenv.mkDerivation {
            name = "about-filter";
            src = about-filter;
            dontUnpack = true;
            nativeBuildInputs = with pkgs; [ gcc ];
            buildPhase = ''
              gcc $src -o filter
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp -v ./filter $out/bin
              chmod +x $out/bin/filter
            '';
            meta.mainProgram = "filter";
          };
        in
        {
          enable = lib.mkForce true;
          virtualHosts."git.weirdfi.sh" = {
            enableACME = true;
            forceSSL = true;
            locations =
              (genAttrs' [ "cgit.css" "cgit.js" "cgit.png" "favicon.ico" ] (
                fileName:
                lib.nameValuePair "= /${fileName}" {
                  alias = lib.mkDefault "${cgit}/cgit/${fileName}";
                }
              ))
              // {
                "~ /.+/(info/refs|git-upload-pack)" = {
                  fastcgiParams = rec {
                    SCRIPT_FILENAME = "${pkgs.git}/libexec/git-core/git-http-backend";
                    PATH_INFO = "$uri";
                    GIT_HTTP_EXPORT_ALL = "1";
                    GIT_PROJECT_ROOT = git-root;
                    HOME = GIT_PROJECT_ROOT;
                  };
                  extraConfig = ''
                    fastcgi_pass unix:${config.services.fcgiwrap.instances."cgit-weirdfish".socket.address};
                  '';
                };
              }
              // {
                "/" = {
                  fastcgiParams = {
                    SCRIPT_FILENAME = "${cgit}/cgit/cgit.cgi";
                    PATH_INFO = "$uri";
                    QUERY_STRING = "$args";
                    CGIT_CONFIG = pkgs.writeText "cgitrc" ''
                      virtual-root=/
                      
                      about-filter=${about-filter'}/bin/filter
                      readme=:README
                      readme=:README.md
                      readme=:README.7

                      enable-blame=1

                      scan-path=${git-root} 

                      repo.url=d1
                      repo.path=/data/git/d1.git
                      repo.desc=jaspine's monorepo
                    '';
                  };
                  extraConfig = ''
                    fastcgi_pass unix:${config.services.fcgiwrap.instances."cgit-weirdfish".socket.address};
                  '';
                };
              };
          };
        };

      system.stateVersion = "24.05";
    });

    flake.deploy.nodes.weirdfish-cax11-4gb = {
      hostname = "weirdfi.sh";
      sshUser = "root";
      remoteBuild = true;
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos flake.nixosConfigurations.weirdfish-cax11-4gb;
      };
    };
  }
