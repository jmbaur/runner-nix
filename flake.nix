{
  description = "runner-nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = inputs: with inputs; {
    apps = import ./apps.nix inputs;
    devShells = import ./devShells.nix inputs;
    nixosModules = import ./nixosModules.nix inputs;
    overlays = import ./overlays.nix inputs;
    packages = import ./packages.nix inputs;
  };
}
