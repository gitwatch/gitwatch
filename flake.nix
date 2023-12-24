{
  description = "A bash script to watch a file or folder and commit changes to a git repo";
  outputs = { self, nixpkgs, flake-utils }:
    let
      packages = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          packages = rec {
            gitwatch = pkgs.callPackage ./gitwatch.sh { };
            default = gitwatch;
          };
        });
    in
    packages // { modules = [ ./module.nix ]; };
}
