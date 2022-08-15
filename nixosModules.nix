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
            default = [ "8080" ];
            description = ''
              An address that the systemd socket will accept connections on.
              Takes values of the form documented under ListenStream= in man 5
              systemd.socket.
            '';
          };
          limitIntervalMinutes = mkOption {
            type = types.int;
            default = 1;
            description = ''
              An interval (in minutes) that will be used to limit the number of
              runs that occur based on the value of <literal>limit</literal>.
            '';
          };
          limit = mkOption {
            type = types.int;
            default = 1;
            description = ''
              The maximum number of runs that will be allowed to occur within a
              time interval specified by
              <literal>limitIntervalMinutes</literal>.
            '';
          };
          adapter = mkOption {
            type = types.enum [ "none" ];
            description = ''
              The adapter to use to authenticate the request and set the
              environment.
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
            description = "runner-nix run ${name}";
            documentation = [ "https://github.com/jmbaur/runner-nix" ];
            listenStreams = runCfg.listenAddresses;
            socketConfig = {
              TriggerLimitIntervalSec = "${toString runCfg.limitIntervalMinutes}m";
              TriggerLimitBurst = runCfg.limit;
            };
            wantedBy = [ "sockets.target" ];
          };
          service = {
            description = "runner-nix run ${name}";
            documentation = [ "https://github.com/jmbaur/runner-nix" ];
            path = [ pkgs.bash ];
            serviceConfig.ExecStart = "${pkgs.runner-nix}/bin/runner-nix --adapter ${runCfg.adapter} --command '${runCfg.command}'";
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
              listenAddresses = [ "[::1]:8080" ];
              adapter = "none";
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
