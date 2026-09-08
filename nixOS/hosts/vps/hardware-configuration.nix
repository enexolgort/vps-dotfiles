# PLACEHOLDER — DO NOT USE AS-IS.
#
# Unique to this specific VPS instance (disk UUIDs, filesystems, virtio
# vs SATA driver, etc). After booting the NixOS installer on the
# Hostinger VPS (or once you've SSH'd into a fresh NixOS install there),
# run:
#
#   nixos-generate-config --root /mnt   # during install
#   # or, on an already-installed system:
#   sudo nixos-generate-config
#
# Then copy the generated hardware-configuration.nix over this file
# before running nixos-rebuild.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Example content for a typical Hostinger KVM VPS — replace entirely
  # with your generated version:
  # boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  # fileSystems."/" = { device = "/dev/disk/by-uuid/XXXX"; fsType = "ext4"; };
  # swapDevices = [ ];
}
