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
          {
            users = [ "citrus" ];
            keys = keys.ssh.friends.citrus.paths;
          }
          {
            users = [ "natter" ];
            keys = keys.ssh.friends.natter.paths;
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
        "d /data/git          755   root      git"
        "d /data/git/jaspine  755   jaspine   git"
        "d /data/git/citrus   755   citrus    git"
        "d /data/git/natter   755   natter    git"
      ];

      services.gitDaemon = {
        enable = true;
        basePath = "/data/git";
        port = config.by.portmap.internal.git-server;
      };

      environment.etc."profile".text = ''
        #!${pkgs.bash}/bin/bash
        [[ $- != *i* ]] && return
        USERNAME=$(whoami)
        [[ "$USERNAME" == "root" ]] && return
        EXTERNAL_IP=$(curl -s https://ipinfo.io/ip)
        echo "Welcome to the weirdfi.sh Git SSH server. Git repositories are placed
        in /data/git, and the administrator should have configured a writable
        directory for you at /data/git/$USERNAME.

        Note that the weirdfi.sh HTTP endpoint is behind a Cloudflare proxy. In
        order to pull/push to the weirdfi.sh Git server, you must use its
        direct IPv4 address ($EXTERNAL_IP). It is recommended to define this
        IPv4 address in your ~/.ssh/config file for convenience:

          Host weirdfish
            HostName $EXTERNAL_IP
            User $USERNAME

        To configure the weirdfi.sh Git server in your local Git project, run
        the following command:

          git remote add weirdfish $USERNAME@$EXTERNAL_IP:/data/git/$USERNAME/<repo name>.git

        Alternatively, if you have configured an SSH host entry (e.g. weirdfish),
        you may use that instead:

          git remote add weirdfish weirdfish:/data/git/$USERNAME/<repo name>.git

        Afterwards, run these commands to fetch the Git server's history, and
        then configure it as your default Git remote.

          git fetch weirdfish
          git branch -u weirdfish/<branch>

        The weirdfi.sh HTTP endpoint uses cgit to render a web interface. cgit
        will display any world-readable Git repository under /data/git. To
        create a new Git repository, run the following command:

          git init --bare name.git

        cgit will display a description for the repository on the web interface
        by reading the .git/description file inside the Git repository. You can
        configure this file to set a repository description.
          
        Please contact your administrator (Jasper) if you have any issues."

        cd /data/git/$USERNAME
      '';

      # Git user has RO access to all Git repositories.
      users.users.git = {
        isSystemUser = true;
        group = "git";
      };
      users.groups.git = { };

      # citrus,natter have RW access to /data/git/<username>/* repositories.
      users.users.citrus = {
        isNormalUser = true;
        group = "git";
      };
      users.users.natter = {
        isNormalUser = true;
        group = "git";
      };

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
                    '';
                    #repo.url=d1
                    #repo.path=/data/git/d1.git
                    #repo.desc=jaspine's monorepo
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
