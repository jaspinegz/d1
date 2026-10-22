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

  hostName = "weirdfi.sh";
  git-root = "/data/git";

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

      environment.etc."profile.local".source = lib.mkForce ./sshrc;

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

      by.websites =
        let
          domain = "git.weirdfi.sh";
        in
        {
          enable = true;
          sites.${domain} = {
            inherit domain;
            acme.enable = true;
            cloudflare.enable = true;
            anubis = {
              enable = true;
              ports.bind   = config.by.portmap.internal.anubis + 1;
              ports.target = config.by.portmap.internal.cgit;
            };
            # leave webserver undefined for special cgit fastcgi
          };
        };

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
          about-filter = pkgs.writeText "filter.c" (import ./_filter.c.nix { inherit pkgs; });
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
          virtualHosts."cgit-post-filter" = {
            listen = [
              {
                addr = "[::1]";
                port = config.by.portmap.internal.cgit;
              }
            ];
            serverName = "git.weirdfi.sh";
            extraConfig = ''
              port_in_redirect off;
            '';
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
                  };
                  extraConfig = ''
                    fastcgi_pass unix:${config.services.fcgiwrap.instances."cgit-weirdfish".socket.address};
                  '';
                };
              };
          };
        };

      systemd.services."git.weirdfi.sh-mirrors" =
        let
          mirror = pkgs.writeText "mirror.c" (import ./_mirror.c.nix { inherit pkgs; });
          mirror' = pkgs.stdenv.mkDerivation {
            name = "mirror";
            src = mirror;
            dontUnpack = true;
            nativeBuildInputs = with pkgs; [ gcc ];
            buildPhase = ''
              gcc $src -o a.out
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp -v ./a.out $out/bin/mirror
              chmod +x $out/bin/mirror
            '';
            meta.mainProgram = "mirror";
          };
        in
        {
          enable = true;
          path = with pkgs; [ git ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeScript "mirror.sh" ''
              #!${pkgs.bash}/bin/bash
              set -x
              ${mirror'}/bin/mirror ${git-root}/jaspine/MIRRORFILE || true
              ${mirror'}/bin/mirror ${git-root}/citrus/MIRRORFILE || true
              ${mirror'}/bin/mirror ${git-root}/natter/MIRRORFILE || true
            '';
          };
        };

      systemd.timers."git.weirdfi.sh-mirrors" = {
        enable = true;
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 05:00:00";
          Persistent = true;
        };
      };

      age.secrets = {
        restic-password.file = "${inputs.agenix-secrets}/agenix/${hostName}/restic-password.age";
        restic-envvars.file = "${inputs.agenix-secrets}/agenix/${hostName}/restic-envvars.age";
      };

      by.restic.enable = true;
      by.restic.defaults = {
        initialize = true;
        pruneOpts = [
          "--keep-monthly=28"
        ];
        timerConfig = {
          OnCalendar = "*-*-* 06:00:00";
          Persistent = true;
        };
        repository = "s3:s3.eu-central-1.s4.mega.io/restic-git.weirdfi.sh";
        passwordFile = config.age.secrets.restic-password.path;
        environmentFile = config.age.secrets.restic-envvars.path;
        progressFps = 0.5;
      };
      # TODO: WARNING: pruneOpts are currently global
      by.restic.backups = {
        git-weirdfish = {
          paths = [ "/data/git" ];
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
