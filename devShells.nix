inputs: with inputs; flake-utils.lib.eachDefaultSystemMap (system:
  let
    pkgs = import nixpkgs { inherit system; };
  in
  {
    default = pkgs.mkShell {
      buildInputs = with pkgs; [
        cargo
        pkg-config
        rustc
        systemdMinimal
      ];
    };
  }
)
