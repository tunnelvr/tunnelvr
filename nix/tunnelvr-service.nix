{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tunnelvr;
in
{
  options.services.tunnelvr = {
    enable = mkEnableOption "The TunnelVR service";

    userDir = mkOption {
      type = types.path;
      default = "/var/lib/tunnelvr";
      description = "the directory to store all user data";
    };

  };

  config = mkIf cfg.enable {
    systemd.services.tunnelvr = {
      description = "TunnelVR Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "networking.target" ];
      serviceConfig = {
        DynamicUser = true;
        Environment = [
          "HOME=${cfg.userDir}"
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${pkgs.tunnelvr_headless}/bin/tunnelvr_headless";
        PrivateTmp = true;
        Restart = "always";
        StateDirectory = "tunnelvr";
        WorkingDirectory = "${cfg.userDir}";
      };
    };
  };
}
