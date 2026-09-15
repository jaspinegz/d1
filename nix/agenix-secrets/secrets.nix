let
  inherit (import ../default.nix) inputs;
  inherit (inputs.nixpkgs) lib;
  flake = import ../default.nix;
  keys  = flake.outputs.flakeModules.berry-keys;
  withDefault = k: (k ++ keys.ssh.groups.privileged.keys);
in
with keys.ssh.groups;
with keys.ssh.hosts;

{
  # GitHub
  "agenix/nix/github-access-token.age".publicKeys = keys.ssh.groups.privileged.keys;
  # Nix
  "agenix/nix/berry-privileged.age".publicKeys = keys.ssh.groups.privileged.keys;
  ### Wireguard
  "agenix/wireguard/001-key.age".publicKeys = (withDefault hyperberry.keys);
  ### Tailscale
  # hosts
  "agenix/tailscale/hosts/hyperberry.age".publicKeys   = (withDefault hyperberry.keys);
  "agenix/tailscale/hosts/blueberry.age".publicKeys    = (withDefault blueberry.keys);
  "agenix/tailscale/hosts/publicproxy.age".publicKeys  = (withDefault publicproxy.keys);
  "agenix/tailscale/hosts/piberry.age".publicKeys      = (withDefault piberry.keys);
  "agenix/tailscale/hosts/tauberry.age".publicKeys     = (withDefault tauberry.keys);
  "agenix/tailscale/hosts/fooberry.age".publicKeys     = (withDefault fooberry.keys);
  # guests
  "agenix/tailscale/guests/vm-gos-update-server.age".publicKeys = (withDefault vm-gos-update-server.keys);
  "agenix/tailscale/guests/vm-immich.age".publicKeys       = (withDefault vm-immich.keys);
  "agenix/tailscale/guests/vm-jellyfin.age".publicKeys     = (withDefault vm-jellyfin.keys);
  "agenix/tailscale/guests/vm-trilium.age".publicKeys      = (withDefault vm-trilium.keys);
  "agenix/tailscale/guests/vm-vikunja.age".publicKeys      = (withDefault vm-vikunja.keys);
  "agenix/tailscale/guests/vx-jupiter.age".publicKeys      = (withDefault vx-jupiter.keys);
  # hyperberry
  "agenix/backup/restic-password.age".publicKeys     = (withDefault hyperberry.keys);
  "agenix/backup/restic-envvars.age".publicKeys      = (withDefault hyperberry.keys);
  "agenix/hyperberry/jenkins-gpg-key.age".publicKeys = (withDefault hyperberry.keys);
  "agenix/hyperberry/jjb-token.age".publicKeys       = (withDefault hyperberry.keys);
  # fooberry
  "agenix/fooberry/cloudflare-key.age".publicKeys    = (withDefault fooberry.keys);
  "agenix/fooberry/Wi-Fi.age".publicKeys             = (withDefault fooberry.keys);
  # piberry
  "agenix/piberry/cloudflare-key.age".publicKeys     = (withDefault wg.keys);
  # tauberry
  "agenix/tauberry/mopidy-conf.age".publicKeys       = (withDefault tauberry.keys);
  # weirdfi.sh
  "agenix/weirdfi.sh/cloudflare-key.age".publicKeys  = (withDefault vm-gos-update-server.keys);
  # wg
  "agenix/wg/Wi-Fi.age".publicKeys = (withDefault wg.keys);
}
