{
  description = "runner-nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = inputs: with inputs; flake-utils.lib.eachSystem [ "aarch64-linux" "x86_64-linux" ]
    (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
        preCommitCheck = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            cargo-check.enable = true;
            clippy.enable = true;
            rustfmt.enable = true;
            nixpkgs-fmt.enable = true;
          };
        };
      in
      {
        apps.default = { type = "app"; program = "${pkgs.runner-nix}/bin/runner-nix"; };
        packages.default = pkgs.runner-nix;
        packages.test = pkgs.callPackage ./test.nix {
          nixosModule = self.nixosModules.default;
        };
        devShells.default = pkgs.mkShell {
          RUST_LOG = "debug";
          buildInputs = with pkgs; [
            just
            entr
            fd
            hello
            systemdMinimal
          ] ++ pkgs.runner-nix.buildInputs;
          inherit (pkgs.runner-nix) nativeBuildInputs;
          inherit (preCommitCheck) shellHook;
        };
      }) // {
    nixosModules.default = {
      nixpkgs.overlays = [ self.overlays.default ];
      imports = [ ./module.nix ];
    };
    overlays.default = _: prev: { runner-nix = prev.callPackage ./. { }; };
  };
}
