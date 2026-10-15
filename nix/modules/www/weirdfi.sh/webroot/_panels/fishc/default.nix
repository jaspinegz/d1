{
  pkgs,
}:

import ./package.nix {
  inherit pkgs;
  inherit (pkgs) stdenv;
}
