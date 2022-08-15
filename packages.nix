inputs: with inputs; flake-utils.lib.eachDefaultSystemMap (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ self.overlays.default ];
    };
  in
  {
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
  })
