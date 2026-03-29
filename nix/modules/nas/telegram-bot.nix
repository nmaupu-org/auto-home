{ config, lib, pkgs, ... }:

# Telegram bot daemon — responds to commands sent to the NAS bot.
# Only accepts messages from the authorized chat_id (set in secrets).
#
# Available commands:
#   /help     — list commands
#   /df       — disk usage
#   /zpool    — ZFS pool status
#   /smart    — SMART health summary for all drives
#   /k3s      — Kubernetes pods
#   /services — status of key services
#   /uptime   — system uptime
#   /mem      — memory usage

let
  botScript = pkgs.writers.writePython3Bin "telegram-bot" {} (builtins.readFile ./telegram-bot.py);
in
{
  systemd.services.telegram-bot = {
    description = "Telegram NAS bot";
    after       = [ "network-online.target" "sops-nix.service" ];
    wants       = [ "network-online.target" ];
    wantedBy    = [ "multi-user.target" ];

    path = with pkgs; [
      zfs smartmontools k3s util-linux gawk
      gnused coreutils bash procps
    ];

    serviceConfig = {
      ExecStart      = "${botScript}/bin/telegram-bot";
      Restart        = "on-failure";
      RestartSec     = "10s";
      User           = "root";
      StandardOutput = "journal";
      StandardError  = "journal";
    };
  };
}
