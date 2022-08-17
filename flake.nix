{
  description = "runner-nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = inputs: with inputs; flake-utils.lib.eachSystem [ "aarch64-linux" "x86_64-linux" ]
    (system:
      let pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; }; in
      {
        apps.default = { type = "app"; program = "${pkgs.runner-nix}/bin/runner-nix"; };
        packages = {
          default = pkgs.runner-nix;
          hello-test = pkgs.nixosTest {
            name = "hello";
            nodes = {
              runner = { pkgs, ... }: {
                imports = [ self.nixosModules.default ];
                services.runner = {
                  enable = true;
                  runs.hello = {
                    listenAddresses = [ "8000" "8001" ];
                    adapter = "none";
                    command = "${pkgs.hello}/bin/hello";
                    # Enforces a maximum of 2 hits per minute.
                    limitIntervalMinutes = 1;
                    limit = 2;
                  };
                };
              };
            };
            testScript = ''
              runner.wait_for_unit("runner@hello.socket")
              runner.succeed("curl -s localhost:8000")
              runner.wait_for_console_text("Hello, world!")
              runner.succeed("curl -s localhost:8001")
              runner.wait_for_console_text("Hello, world!")
              runner.fail("curl -s localhost:8000")
            '';
          };
        };
        devShells.default = pkgs.mkShell {
          inherit (self.packages.${system}.default) SYSTEMD_LIB_DIR;
          inherit (pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              cargo-check.enable = true;
              # TODO(jared): invalid metadata found in nix store
              clippy.enable = false;
              rustfmt.enable = true;
              nixpkgs-fmt.enable = true;
            };
          }) shellHook;
          RUST_LOG = "debug";
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
      })
  //
  {
    nixosModules = import ./nixosModules.nix inputs;
    overlays.default = _: prev: { runner-nix = prev.callPackage ./. { }; };
  };
}
