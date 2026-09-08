# configuration.nix — the real-machine target (this VPS has an actual
# disk and bootloader). Everything not specific to that lives in ./common/.
{ config, pkgs, lib, vars, ... }:

{
  boot.loader.systemd-boot.enable = lib.mkIf (vars.bootloader == "systemd-boot") true;
  boot.loader.systemd-boot.configurationLimit = lib.mkIf (vars.bootloader == "systemd-boot") 10;
  boot.loader.efi.canTouchEfiVariables = lib.mkIf (vars.bootloader == "systemd-boot") true;

  boot.loader.grub.enable = lib.mkIf (vars.bootloader == "grub") true;
  boot.loader.grub.device = lib.mkIf (vars.bootloader == "grub") vars.grubDevice;

  networking.networkmanager.enable = true;

  # --- Extra storage drives, if any (declared in vars.nix) -------------
  fileSystems = builtins.listToAttrs (map
    (m: {
      name = m.mountPoint;
      value = {
        device = m.device;
        fsType = m.fsType or "ext4";
        options = m.options or [ "defaults" "nofail" ];
      };
    })
    vars.extraMounts);

  imports = [ ./common ];
}
