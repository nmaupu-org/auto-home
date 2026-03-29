{ config, lib, pkgs, ... }:

# Note: paths use /tank/... (no altroot) — verify actual mountpoints after
# `zpool import tank` and adjust if needed.
#
# Samba users (nmaupu, bicou) must exist as system users and have a samba
# password set. Passwords are wired via sops-nix (see secrets/nas.yaml).
# Until sops is in place, set manually: smbpasswd -a <user>

{
  services.samba = {
    enable = true;
    openFirewall = true;

    settings = {
      global = {
        workgroup     = "WORKGROUP";
        "server string" = "nas";

        # macOS / AFP compatibility
        "vfs objects"                            = "catia fruit streams_xattr";
        "fruit:metadata"                         = "stream";
        "fruit:model"                            = "MacSamba";
        "fruit:posix_rename"                     = "yes";
        "fruit:veto_appledouble"                 = "no";
        "fruit:wipe_intentionally_left_blank_rfork" = "yes";
        "fruit:delete_empty_adfiles"             = "yes";
      };

      # Printer share — TrueNAS used zfs_space/zfsacl VFS modules which are
      # not available in upstream Samba; dropped here.
      "printer" = {
        path              = "/tank/ftp_home/printer";
        browseable        = "yes";
        "read only"       = "no";
        "guest ok"        = "no";
        oplocks           = "no";
        "level2 oplocks"  = "no";
        "strict locking"  = "auto";
      };

      "home-bicou" = {
        path                   = "/tank/home/bicou";
        browseable             = "yes";
        "read only"            = "no";
        "guest ok"             = "no";
        "valid users"          = "nmaupu bicou";
        "create mask"          = "0755";
        "directory mask"       = "0755";
        "force create mode"    = "0";
        "force directory mode" = "0";
      };

      # Time Machine backup for MacBook Air (nmaupu)
      "backup-air" = {
        path                   = "/tank/backup-mac-air";
        browseable             = "yes";
        "read only"            = "no";
        "guest ok"             = "no";
        "valid users"          = "nmaupu";
        "create mask"          = "0755";
        "directory mask"       = "0755";
        "force create mode"    = "0644";
        "force directory mode" = "0755";
        "fruit:time machine"   = "yes";
      };

      "photos" = {
        path                   = "/tank/photos";
        browseable             = "yes";
        "read only"            = "no";
        "guest ok"             = "no";
        "valid users"          = "nmaupu";
        "create mask"          = "0777";
        "directory mask"       = "0777";
        "force create mode"    = "0755";
        "force directory mode" = "0644";
      };

      # Time Machine backup for MacBook Pro (bicou + nmaupu)
      # %U creates a per-user subdirectory automatically
      "backup-pro-bicou" = {
        path                   = "/tank/backup-mac-pro-bicou/%U";
        browseable             = "yes";
        "read only"            = "no";
        "guest ok"             = "no";
        "valid users"          = "bicou nmaupu";
        "create mask"          = "0777";
        "directory mask"       = "0777";
        "force create mode"    = "0644";
        "force directory mode" = "0744";
        "fruit:time machine"   = "yes";
      };

      "dls" = {
        path        = "/tank/dls";
        browseable  = "yes";
        "read only" = "no";
        "guest ok"  = "no";
      };
    };
  };

  # Network discovery (makes the NAS show up in Finder / Windows Explorer)
  services.samba-wsdd.enable = true;

  # Avahi — mDNS/Bonjour advertisement required for Time Machine over SMB
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  sops.secrets.smb_nmaupu_password = { sopsFile = ../../secrets/nas.yaml; };
  sops.secrets.smb_bicou_password  = { sopsFile = ../../secrets/nas.yaml; };

  # Set Samba passwords from sops secrets on every activation
  system.activationScripts.samba-passwords = {
    deps = [ "setupSecrets" ];
    text = ''
      for user in nmaupu bicou; do
        secret="/run/secrets/smb_''${user}_password"
        if [ -f "$secret" ]; then
          ${pkgs.samba}/bin/smbpasswd -s -a "$user" <<EOF
$(cat "$secret")
$(cat "$secret")
EOF
        fi
      done
    '';
  };
}
