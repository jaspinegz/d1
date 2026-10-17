{
  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      package = pkgs.callPackage ./package.nix { target = "index.html"; };
      shaders = pkgs.callPackage ./shaders { };
    in
    {
      packages.default = package;
      packages.fishc = package;

      packages.fishc-shader-tank = shaders.tank.drv;
      packages.fishc-shader-fish = shaders.fish.drv;
      packages.fishc-shader-dither = shaders.dither.drv;

      devShell = pkgs.mkShell rec {
        inherit (package) nativeBuildInputs buildInputs;
        #LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath package.buildInputs;
      };
    });
}
