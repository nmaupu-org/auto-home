{ config, lib, pkgs, ... }:

# Common baseline for all NixOS hosts:
# - shared packages including update-system script (flake target is configurable)
# - nix settings (flakes, GC, optimise)
# - sops age key from SSH host key
#
# Usage — set the flake target in the host configuration:
#   services.base.flakeTarget = "iot";

{
  options.services.base.flakeTarget = lib.mkOption {
    type        = lib.types.str;
    description = "Flake target name used by the update-system script (e.g. nas, iot)";
  };

  config = {
    environment.variables.EDITOR = "vim";

    environment.systemPackages = with pkgs; [
      age
      dnsutils
      git
      inetutils
      jq
      k9s
      kubectl
      sops
      ssh-to-age
      tree
      vim
      zsh
      (writeShellScriptBin "update-system" ''
        set -e
        cd /root/auto-home
        git fetch --all
        git reset --hard origin/master
        nixos-rebuild switch --flake ./nix#${config.services.base.flakeTarget}
      '')
    ];

    services.journald.extraConfig = "Storage=persistent\n";

    # Reboot automatically after a kernel panic (10s delay)
    boot.kernel.sysctl."kernel.panic"              = 10;
    boot.kernel.sysctl."kernel.panic_on_oops"      = 1;
    # Reboot on soft lockup or hung task (otherwise the machine freezes silently)
    boot.kernel.sysctl."kernel.softlockup_panic"   = 1;
    boot.kernel.sysctl."kernel.hung_task_panic"    = 1;

    # Alert via Telegram (if available) when coming back after a crash
    systemd.services.crash-alert = {
      description = "Notify Telegram if previous boot ended unexpectedly";
      after    = [ "network-online.target" "sops-nix.service" ];
      wants    = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type            = "oneshot";
        User            = "root";
        RemainAfterExit = false;
      };
      script = ''
        # Skip if telegram-alert is not configured on this host
        [ -x /etc/telegram-alert ] || exit 0
        # Skip if there is no previous boot in the journal
        ${pkgs.systemd}/bin/journalctl --list-boots --no-pager -q 2>/dev/null \
          | grep -qE '^\s*-1\s' || exit 0
        # A clean shutdown always logs "Reached target System Shutdown"
        if ! ${pkgs.systemd}/bin/journalctl -b -1 --no-pager -q 2>/dev/null \
            | grep -q "Reached target.*Shutdown"; then
          /etc/telegram-alert "⚠️ ${config.networking.hostName} rebooted after an unclean shutdown (crash or power loss)"
        fi
      '';
    };

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.download-buffer-size = 524288000; # 500MiB

    nix.gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 30d";
    };
    nix.settings.auto-optimise-store = true;

    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Clone auto-home repo on first boot if not already present
    systemd.services.clone-auto-home = {
      description = "Clone auto-home repository";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "!/root/auto-home";
      serviceConfig = {
        Type            = "oneshot";
        User            = "root";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.git}/bin/git clone https://github.com/nmaupu-org/auto-home.git /root/auto-home
      '';
    };
  };
}
