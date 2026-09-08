{
  inputs,
  lib,
  prebuiltPackages,
  ...
} @args:

let
  inherit (args.config) flake;
in
{
  flake.metadata.blueberry = {
    type = flake.things.host;
    description = ''
      My daily driver Linux desktop. It's called blueberry because the case is
      blue. The similarities with blueberries end there.
    '';
    attributes = {
      uplinks.tailscale0.ipAddress = "100.64.*.*";
    };
  };

  flake.nixosConfigurations.blueberry = inputs.self.lib.mkNixOS rec {
      system = "x86_64-linux";
      specialArgs = {
        pkgs = prebuiltPackages.${system};
      };
      modules = with flake.modules;
      [
        (with flake.tags; flake.lib.use [
          flake-default
          nixos-base
          nixos-workstation
          nixos-desktop
        ])
        nixos.blueberry
        nixos.blueberry-hardware
        nixos.blueberry-disk
        nixos.authorized-keys
        ({ config, ... }: {
          by.presets.authorized-keys.groups = [
            {
              users = [ "root" "jaspine" ];
              keys = config.by.keys.ssh.groups.privileged.paths;
            }
          ];
        })
        nixos.avahi
        nixos.desktop-wooting
        nixos.drivers-maccel
        nixos.drivers-nvidia
        nixos.home-manager
        {
          by.presets.home-manager.user = "jaspine";
        }
        home-manager.blueberry
        home-manager.blueberry-hardware
        # Desktop environment
        home-manager.dank-material-shell
        home-manager.desktop-xdg
        home-manager.niri
        home-manager.way-displays
        # Programs
        home-manager.alacritty
        home-manager.ghostty
        home-manager.fish
        # Games
        home-manager.prism-launcher
        # 3rd party modules
        inputs.agenix.nixosModules.default
        inputs.nix-flatpak.nixosModules.nix-flatpak
        {
          #TODO this should be handled already
          xdg.portal.enable = true;
          xdg.portal.extraPortals = with prebuiltPackages.${system}; [
            xdg-desktop-portal-gtk
          ];
          services.flatpak = {
            enable = true;
            packages = [
              "com.infinipaint.infinipaint"
            ];
            update.onActivation = true;
          };
        }
      ];
    };

  flake.modules.nixos.blueberry = flake.lib.nixos.mkAspect (with flake.tags; [ hosts ])
    ({
      lib,
      pkgs,
      config,
      ...
    }:

    let
      keys = config.by.keys;
    in
    {
      # Set your time zone.
      time.timeZone = "Europe/London";
    
      # Select internationalization properties.
      i18n.defaultLocale = "en_GB.UTF-8";
      console = {
        font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
        packages = with pkgs; [ terminus_font ];
        keyMap = "uk";
      };
    
      # Enable sudo.
      security.sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };
    
      # Enable the OpenSSH daemon.
      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
      };
    
      # Enable Fail2Ban for basic intrusion prevention.
      services.fail2ban.enable = true;
    
      services.resolved = {
        enable = true;
      };
    
      # Setup networking.
      networking = {
        hostName = "blueberry";
        enableIPv6 = true;
        nameservers = [
          "1.1.1.1"
          "8.8.8.8"
          "8.8.4.4"
        ];
        firewall = {
          enable = true;
        };
      };
    
      # Define users.
      users.users.jaspine = {
        isNormalUser = true;
        shell = pkgs.fish;
        group = "jaspine";
        extraGroups = [
          "wheel"
          "input"
        ];
        home = "/home/jaspine";
      };
      users.groups.jaspine = { };
      nix.settings.trusted-users = [ "jaspine" ];
    
      age.secrets.tailscale-auth-key.file = "${inputs.agenix-secrets}/agenix/tailscale/hosts/blueberry.age";
    
      services.tailscale = {
        enable = true; 
        authKeyFile = config.age.secrets.tailscale-auth-key.path;
        useRoutingFeatures = lib.mkDefault "both";
      };
    
      programs.steam.enable = true;
      services.dbus.enable = true;
    
      programs.command-not-found.enable = true;
      programs.fish.enable = true;
    
      ##########################################################################################
      # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
      # In the vast majority of cases, do not change this version.
      ##########################################################################################
      system.stateVersion = "25.05";
    });

  flake.modules.home-manager.blueberry = flake.lib.home-manager.mkAspect []
    ({
      lib,
      config,
      pkgs,
      ...
    }:

    let
      pkgs-aseprite = import inputs.nixpkgs-aseprite {
        inherit (pkgs) system;
        config.allowUnfree = true;
      };
    in
    {
      home.stateVersion = "25.05";
      home.packages = with pkgs; [
        # Socials
        vesktop
        signal-desktop
        # Editors
        pkgs-aseprite.aseprite
        darktable
        zed-editor
        helix
        libreoffice
        krita
        # Browsers
        # - firefox included with module
        chromium
        # Music
        feishin
        tidal-hifi
        # Virtualization
        qemu
        #TODO: pin 
        #rpcs3
        eden
        # Media
        vlc
        # Utilities
        wootility
        bitwarden-desktop
      ];
    });

  flake.deploy.nodes.blueberry = {
    hostname = "blueberry";
    sshUser = "jaspine";
    remoteBuild = false;
    profiles.system = {
      user = "root";
      path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos flake.nixosConfigurations.blueberry;
    };
  };
}
