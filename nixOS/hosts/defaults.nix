# hosts/defaults.nix
# Shared config, merged underneath hosts/vps/vars.nix by flake.nix.
# Kept as a separate file (rather than folded into vars.nix directly) so
# the two are easy to tell apart: this is "safe fleet-wide defaults",
# vars.nix is "what's actually specific to this one VPS".
{
  system = "x86_64-linux";

  # No locale/timezone info was given for this machine — set generic
  # defaults and adjust to taste in vars.nix or here.
  timeZone = "UTC";
  locale = "en_US.UTF-8";
  keyMap = "us";

  initialPassword = "changeme"; # change on first login with: passwd <username>

  mediaDir = "/data/media";
  projectsDir = "/data/projects"; # where install.sh clones vars.nix's projectRepos

  sambaWorkgroup = "WORKGROUP";

  extraMounts = [ ];

  secretsEnabled = false;

  notifyWebhook = "";
}
