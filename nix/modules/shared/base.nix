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
    environment.systemPackages = with pkgs; [
      age
      git
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
        cd /home/nmaupu/auto-home
        git fetch --all
        git reset --hard origin/master
        sudo nixos-rebuild switch --flake ./nix#${config.services.base.flakeTarget}
      '')
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.download-buffer-size = 524288000; # 500MiB

    nix.gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 30d";
    };
    nix.settings.auto-optimise-store = true;

    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
