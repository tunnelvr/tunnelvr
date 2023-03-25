{ config, lib, pkgs, self, ... }:

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

    package = mkOption {
      default = self.packages.${pkgs.hostPlatform.system}.tunnelvr-headless_withPrograms;
      defaultText = literalExpression "self.packages.${pkgs.hostPlatform.system}.tunnelvr-headless_withPrograms;";
      type = types.package;
      description = lib.mdDoc "TunnelVR package to use.";
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
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.package}/bin/tunnelvr-headless";
        PrivateTmp = true;
        Restart = "always";
        StateDirectory = "tunnelvr";
        WorkingDirectory = "${cfg.userDir}";
      };
    };
  };
}
