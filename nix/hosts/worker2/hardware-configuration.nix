# Placeholder copied from worker1 (same Firebat N100 hardware).
# Regenerate on the live worker2 with:
#   nixos-generate-config --root /mnt --no-filesystems
# then copy the result over this file.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/sys-root";
      fsType = "ext4";
    };

  fileSystems."/boot/efi" =
    { device = "/dev/disk/by-uuid/BECB-493F";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/var/lib/rancher/k3s" =
    { device = "/dev/mapper/sys-containerd";
      fsType = "ext4";
    };

  fileSystems."/var/openebs/local" =
    { device = "/dev/mapper/sys-data";
      fsType = "ext4";
    };

  fileSystems."/var/lib/longhorn" =
    { device = "/dev/sys/data-longhorn";
      fsType = "ext4";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
