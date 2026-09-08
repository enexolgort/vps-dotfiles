# common/base.nix — system identity, Nix itself, secrets, the user
# account.
{ config, pkgs, lib, vars, ... }:

{
  networking.hostName = vars.hostname;

  time.timeZone = vars.timeZone;
  i18n.defaultLocale = vars.locale;
  console.keyMap = vars.keyMap;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ======================================================================
  # SECRETS (sops-nix) — see doc/secrets.md for one-time setup. Off by
  # default (vars.secretsEnabled = false); the plaintext values in
  # vars.nix keep working until you complete that setup and flip it on.
  #
  # LIMITATION: CouchDB's `adminPass` option only accepts a literal Nix
  # string, not a file path — so it always ends up readable in the Nix
  # store regardless of sops-nix. Mitigated by: CouchDB is tailnet-only
  # (see networking.nix), so this isn't exposed to the internet either way.
  # ======================================================================
  sops = lib.mkIf vars.secretsEnabled {
    defaultSopsFile = ../secrets.yaml; # install.sh copies this into /etc/nixos too — see doc/secrets.md
    age.keyFile = "/var/lib/sops-nix/key.txt"; # generated once during setup, see doc/secrets.md
    secrets = {
      userPasswordHash = {};
      backupPassword = {};
    };
  };

  # --- User account ----------------------------------------------------
  # Set a real password after first boot with: passwd <username>
  # (or, once vars.secretsEnabled is true, the password comes from the
  # sops-managed hash instead — see doc/secrets.md)
  users.groups.media = {};

  users.users.${vars.username} = {
    isNormalUser = true;
    description = "VPS admin";
    extraGroups = [ "wheel" "jellyfin" "docker" "media" ];
    shell = pkgs.bash;
  } // (if vars.secretsEnabled
    then { hashedPasswordFile = config.sops.secrets.userPasswordHash.path; }
    else { initialPassword = vars.initialPassword; }); # CHANGE on first login

  system.stateVersion = "24.11"; # do not change after initial install
}
