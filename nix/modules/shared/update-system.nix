{ config, lib, pkgs, ... }:

# Shared auto-update module: pulls latest git and rebuilds NixOS.
# On failure, triggers the update-system-failure@ notifier from telegram.nix.
# Also runs a heartbeat every 10 minutes so healthchecks.io knows the machine is alive.
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
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Whether to enable the automatic update timer. The update-system script remains available manually.";
    };

    hostName = lib.mkOption {
      type        = lib.types.str;
      description = "Flake hostname used in: nixos-rebuild switch --flake ./nix#<hostName>";
    };

    hcPingUUID = lib.mkOption {
      type        = lib.types.str;
      description = "healthchecks.io check UUID for the heartbeat timer";
    };

    onCalendar = lib.mkOption {
      type    = lib.types.str;
      default = "*-*-* 00/6:00:00";
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
      script = ''
        cd /root/auto-home
        ${pkgs.git}/bin/git fetch --all
        ${pkgs.git}/bin/git reset --hard origin/master
        ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ./nix#${cfg.hostName}
      '';
    };

    systemd.timers.update-system = lib.mkIf cfg.enable {
      description = "Daily NixOS system update";
      wantedBy    = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent  = true;
      };
    };

    systemd.services.hc-heartbeat = {
      description = "Ping healthchecks.io to signal machine is alive";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        ${pkgs.curl}/bin/curl -fsS --retry 3 https://hc-ping.com/${cfg.hcPingUUID} > /dev/null
      '';
    };

    systemd.timers.hc-heartbeat = {
      description = "Heartbeat ping to healthchecks.io every 10 minutes";
      wantedBy    = [ "timers.target" ];
      timerConfig = {
        OnBootSec   = "1min";
        OnUnitActiveSec = "10min";
      };
    };
  };
}
