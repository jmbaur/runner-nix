# runner-nix

This repo provides a module and a small program that wraps a command to run as
part of a CI/CD flow. The program performs authentication from a trigger for
kicking off a pipeline (e.g. GitHub) as well as sets up an appropriate
environment prior to performing the run.

## Usage:

Consume this flake's outputs (in your flake.nix):
```nix
inputs = {
  runner-nix.url = "github:jmbaur/runner-nix";
};

outputs = { nixpkgs, runner-nix, ... }: {
  nixosConfigurations.runner-node = nixpkgs.lib.nixosSystem {
    modules = [
      { nixpkgs.overlays = [ runner-nix.overlays.default ]; }
      runner-nix.nixosModules.default
      ./configuration.nix
    ];
  };
};
```

Configure the runner (in your configuration.nix):
```nix
{ config, pkgs, ... }: {
  services.runner = {
    enable = true;
    runs.hello = {
      adapter = "github";
      command = "${pkgs.hello}/bin/hello";
    };
  };
}
```

Point your supported adapter to your runner node (default port is 8000), then
kick off a run. For this example, you would need to set up a GitHub webhook on
push. Logs for this example run would be available at `journalctl -fu runner@hello.service`.
