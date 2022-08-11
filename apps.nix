inputs: with inputs;flake-utils.lib.eachDefaultSystemMap (system:
  let
    pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
  in
  {
    default = { type = "app"; program = "${pkgs.runner-nix}/bin/runner-nix"; };
  })
