# hosts/vps/vars.nix — this machine: a Hostinger VPS.
{
  hostname = "vps";
  username = "deploy"; # CHANGE if you'd rather log in as something else
  gitEmail = "enexolgort94@gmail.com";

  # Hostinger's KVM VPS plans present the disk as a virtio device
  # (/dev/vda), not a SATA/SCSI one (/dev/sda) — verify with `lsblk` or
  # `sudo parted /dev/vda -- print` on first boot and adjust if wrong.
  #
  # GRUB rather than systemd-boot: most Hostinger VPS plans still boot
  # BIOS/legacy rather than UEFI (same failure mode the inspiration repo
  # hit — "efiSysMountPoint = '/boot' is not a mounted partition" — is
  # what systemd-boot gives you on a BIOS-booted box). Confirm via
  # `sudo parted /dev/vda -- print`: "msdos" = BIOS (stick with grub),
  # "gpt" = UEFI (systemd-boot is fine, switch bootloader below).
  bootloader = "grub";
  grubDevice = "/dev/vda";

  # --- Services -----------------------------------------------------
  # Everything headless previously ran (Obsidian sync, git server, n8n)
  # merged onto vps, plus vps's own local AI stack.
  jellyfinEnable = false;
  obsidianEnable = true;
  gitServerEnable = true;
  aiEnable = true; # Ollama + Open WebUI — see common/ai.nix
  sftpEnable = false;
  n8nEnable = true;
  monitoringHubEnable = false;

  # CPU-only inference — start conservative and size up once you know
  # this VPS plan's actual RAM/core count (`nproc`, `free -h`).
  aiModels = [ "qwen2.5:7b" ];

  # obsidianEnable = true, so these need to actually be here.
  couchdbAdminUser = "admin";
  couchdbAdminPass = "changeme-couchdb"; # CHANGE THIS

  # gitServerEnable = true, so these need to actually be here.
  # NOTE: "admin" itself is a reserved username in Forgejo.
  gitAdminUser = "enexolgort";
  gitAdminPass = "changeme-git"; # CHANGE THIS

  backupEnable = false;

  projectRepos = [ ];
}
