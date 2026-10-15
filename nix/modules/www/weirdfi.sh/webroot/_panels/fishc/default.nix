{
  pkgs,
  target ? "index.js",
}:

import ./package.nix {
  inherit pkgs target;
  inherit (pkgs) stdenv;
}
