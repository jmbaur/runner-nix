inputs: with inputs;
{
  default = { config, lib, pkgs, ... }:
    with lib;
    let
      cfg = config.services.runner;

      runSubmodule = { name, ... }: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
            description = ''
              The name of the run.
            '';
          };
          listenAddresses = mkOption {
            type = with types; listOf str;
            default = [ "/run/runner/${name}.sock" ];
            description = ''
              An address that the systemd socket will accept connections on.
            '';
          };
          command = mkOption {
            type = types.str;
            description = ''
              A command for the runner to run.
            '';
          };
        };
      };

      systemdUnits = lib.mapAttrs
        (name: runCfg: {
          socket = {
            description = "runner.nix run ${name}";
            documentation = [ "https://github.com/jmbaur/runner.nix" ];
            listenStreams = runCfg.listenAddresses;
            wantedBy = [ "sockets.target" ];
          };
          service = {
            description = "runner.nix run ${name}";
            documentation = [ "https://github.com/jmbaur/runner.nix" ];
            serviceConfig.ExecStart = "${pkgs.runner-nix}/bin/runner-nix -- ${runCfg.command}";
          };
        })
        cfg.runs;
    in
    {
      options.services.runner = {
        enable = mkEnableOption "runner service";
        runs = mkOption {
          type = with types; attrsOf (submodule runSubmodule);
          example = {
            hello = {
              listenAddresses = [ "[::1]:8000" ];
              command = "${pkgs.hello}/bin/hello";
            };
          };
        };
      };

      config = lib.mkIf cfg.enable {
        nixpkgs.overlays = [ self.overlays.default ];

        systemd.sockets = lib.mapAttrs'
          (name: units: lib.nameValuePair "runner@${name}" units.socket)
          systemdUnits;

        systemd.services = lib.mapAttrs'
          (name: units: lib.nameValuePair "runner@${name}" units.service)
          systemdUnits;
      };
    };
}
