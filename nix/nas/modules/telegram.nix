{ config, lib, pkgs, ... }:

# Shared Telegram alert script consumed by smartd, zed, and systemd units.
#
# Secrets are managed via sops-nix. Before activating this module:
#   1. Generate the NAS age key: ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
#   2. Update .sops.yaml with the age public key
#   3. Create secrets: sops secrets/secrets.yaml
#      and fill in telegram_token and telegram_chat_id
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
        --data-urlencode "text=[nas] ''${MESSAGE}" \
        > /dev/null
    '';
  };
in
{
  sops.secrets.telegram_token   = { sopsFile = ../secrets/secrets.yaml; mode = "0444"; };
  sops.secrets.telegram_chat_id = { sopsFile = ../secrets/secrets.yaml; mode = "0444"; };

  environment.systemPackages = [ telegram-alert ];

  # Stable path for other services (smartd, zed) to reference
  environment.etc."telegram-alert" = {
    source = "${telegram-alert}/bin/telegram-alert";
    mode   = "0755";
  };
}
