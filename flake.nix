{
  description = "runner.nix";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: with inputs; {
    apps = import ./apps.nix inputs;
    devShells = import ./devShells.nix inputs;
    nixosModules = import ./nixosModules.nix inputs;
    overlays = import ./overlays.nix inputs;
    packages = import ./packages.nix inputs;
  };
}
