inputs: with inputs; flake-utils.lib.eachDefaultSystemMap (system:
  let
    pkgs = import nixpkgs { inherit system; };
  in
  {
    default = pkgs.mkShell {
      inherit (self.packages.${system}.default) SYSTEMD_LIB_DIR;
      inherit (pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          cargo-check.enable = true;
          # TODO(jared): invalid metadata found in  nix store
          clippy.enable = false;
          rustfmt.enable = true;
          nixpkgs-fmt.enable = true;
        };
      }) shellHook;
      buildInputs = with pkgs; [
        cargo
        rustc
        rustfmt
        (writeShellScriptBin "run" ''
          ${fd}/bin/fd -e rs |
            ${entr}/bin/entr -c \
              sh -c 'cargo build && ${systemdMinimal}/bin/systemd-socket-activate -l8000 -l8080 ./target/debug/runner-nix --adapter none --command ${hello}/bin/hello'
        '')
      ];
    };
  }
)
