# Deploy to the Hostinger VPS

1. **Boot the NixOS installer** on the VPS (Hostinger's hPanel lets you mount a custom ISO / use their OS templates for the KVM console — check their docs for the current method), partition/mount disks, then:
   ```bash
   nixos-generate-config --root /mnt
   ```
   Copy the generated `/mnt/etc/nixos/hardware-configuration.nix` over the placeholder at `nixOS/hosts/vps/hardware-configuration.nix` in this repo.

2. **Confirm BIOS vs UEFI** before trusting the `bootloader` setting already in `vars.nix`:
   ```bash
   sudo parted /dev/vda -- print   # or /dev/sda if that's what lsblk shows
   ```
   `msdos` partition table → BIOS → keep `bootloader = "grub"`. `gpt` → UEFI → you can switch to `bootloader = "systemd-boot"` instead.

3. **Edit `nixOS/hosts/vps/vars.nix`** to taste (username, real passwords, `grubDevice`/`gitEmail` — see [configuration.md](./configuration.md)).

4. **Copy the whole `nixOS/` folder** to `/mnt/etc/nixos/`.

5. **Install**:
   ```bash
   nixos-install --flake /mnt/etc/nixos#vps
   ```
   Set the root password, reboot.

6. Log in as the username from `vars.nix` (password `initialPassword` from `hosts/defaults.nix` — **change it immediately** with `passwd`).

7. Continue with [first-boot-setup.md](./first-boot-setup.md).

[← back to overview](./overview.md)
