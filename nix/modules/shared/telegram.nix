{ config, lib, pkgs, ... }:

# Shared Telegram alert script consumed by smartd, zed, and systemd units.
#
# Usage — in the host configuration, set the sops file before importing:
#   services.telegram-alert.sopsFile = ../../secrets/nas.yaml;
#
# The secrets file must contain: telegram_token, telegram_chat_id
#
# Script calling conventions supported:
#   - smartd (-M exec): called as `script -s "subject" address` (body on stdin)
#   - direct:           called as `script "message"`

let
  telegram-alert = pkgs.writeShellApplication {
    name = "telegram-alert";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      TELEGRAM_TOKEN=$(cat /run/secrets/telegram_token)
      TELEGRAM_CHAT_ID=$(cat /run/secrets/telegram_chat_id)

      if [ "''${1:-}" = "-s" ]; then
        # smartd / sendmail-style: script -s "subject" address
        MESSAGE="''${2:-}"
      else
        MESSAGE="''${*:-no message}"
      fi

      curl -s -X POST \
        "https://api.telegram.org/bot''${TELEGRAM_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=''${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=''${MESSAGE}" \
        > /dev/null
    '';
  };
in
{
  options.services.telegram-alert.sopsFile = lib.mkOption {
    type        = lib.types.path;
    description = "sops-encrypted secrets file containing telegram_token and telegram_chat_id";
  };

  config = {
    sops.secrets.telegram_token   = { sopsFile = config.services.telegram-alert.sopsFile; mode = "0444"; };
    sops.secrets.telegram_chat_id = { sopsFile = config.services.telegram-alert.sopsFile; mode = "0444"; };

    environment.systemPackages = [ telegram-alert ];

    # Stable path for other services (smartd, zed) to reference
    environment.etc."telegram-alert" = {
      source = "${telegram-alert}/bin/telegram-alert";
      mode   = "0755";
    };

    # Generic failure notifier — triggered via OnFailure = "update-system-failure@%n.service"
    systemd.services."update-system-failure@" = {
      description = "Notify Telegram on update-system failure";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        /etc/telegram-alert "update-system failed — check: journalctl -u update-system"
      '';
    };
  };
}
