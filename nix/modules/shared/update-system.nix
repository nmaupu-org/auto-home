{ config, lib, pkgs, ... }:

# Shared auto-update module: pulls latest git, rebuilds NixOS, and pings healthchecks.io.
# On failure, triggers the update-system-failure@ notifier from telegram.nix.
#
# Usage — in the host configuration:
#   services.update-system = {
#     hostName    = "nas";
#     hcPingUUID  = "0b248bd0-a4e8-47d3-b2d9-697db7623d48";
#     onCalendar  = "*-*-* 10:00:00";  # optional, default 09:00:00
#   };

let
  cfg = config.services.update-system;
in
{
  options.services.update-system = {
    hostName = lib.mkOption {
      type        = lib.types.str;
      description = "Flake hostname used in: nixos-rebuild switch --flake ./nix#<hostName>";
    };

    hcPingUUID = lib.mkOption {
      type        = lib.types.str;
      description = "healthchecks.io check UUID to ping on successful update";
    };

    onCalendar = lib.mkOption {
      type    = lib.types.str;
      default = "*-*-* 09:00:00";
      description = "systemd OnCalendar expression for the update timer";
    };
  };

  config = {
    systemd.services.update-system = {
      description = "Auto-update NixOS system configuration";
      serviceConfig = {
        Type        = "oneshot";
        User        = "root";
        Environment = "PATH=${pkgs.git}/bin:${pkgs.nixos-rebuild}/bin:${pkgs.curl}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin";
      };
      unitConfig.OnFailure = "update-system-failure@%n.service";
      script = ''
        cd /root/auto-home
        ${pkgs.git}/bin/git fetch --all
        ${pkgs.git}/bin/git reset --hard origin/master
        ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ./nix#${cfg.hostName}
        ${pkgs.curl}/bin/curl -fsS --retry 3 https://hc-ping.com/${cfg.hcPingUUID} > /dev/null
      '';
    };

    systemd.timers.update-system = {
      description = "Daily NixOS system update";
      wantedBy    = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent  = true;
      };
    };
  };
}
