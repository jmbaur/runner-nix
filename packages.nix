inputs: with inputs; flake-utils.lib.eachDefaultSystemMap (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ self.overlays.default ];
    };
  in
  {
    default = pkgs.runner-nix;
    hello-test = pkgs.nixosTest
      {
        name = "hello";
        nodes = {
          runner = { pkgs, ... }: {
            imports = [ self.nixosModules.default ];
            services.runner = {
              enable = true;
              runs.hello = {
                adapter = "none";
                command = "${pkgs.hello}/bin/hello";
              };
            };
          };
        };
        testScript = ''
          runner.wait_for_unit("runner@hello.socket")
          runner.succeed("curl localhost:8080")
          runner.wait_for_console_text("Hello, world!")
        '';
      };
  })
