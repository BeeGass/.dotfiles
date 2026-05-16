# Dataset / ML cache layout on the dedicated XFS NVMe (labeled "data").
#
# Mounted at /data by the host's hardware-configuration.nix via
# /dev/disk/by-label/data. tmpfiles creates the ML subdirs at activation;
# sessionVariables point Hugging Face caches at /data so they don't fill /home.
#
# Safety: if /data is not mounted at activation time (drive missing,
# label mismatch), systemd-tmpfiles would create the dirs on the root
# filesystem instead. The hardware-configuration.nix mount option `nofail`
# keeps boot working without the drive, but the user should `df -h /data`
# after boot to confirm the mount took.
{ vars, ... }:
{
  systemd.tmpfiles.rules = [
    "d /data                0755 ${vars.username} users -"
    "d /data/hf-cache       0755 ${vars.username} users -"
    "d /data/hf-cache/hub   0755 ${vars.username} users -"
    "d /data/datasets       0755 ${vars.username} users -"
    "d /data/models         0755 ${vars.username} users -"
    "d /data/checkpoints    0755 ${vars.username} users -"
    "d /data/scratch        0755 ${vars.username} users -"
  ];

  environment.sessionVariables = {
    HF_HOME = "/data/hf-cache";
    HF_HUB_CACHE = "/data/hf-cache/hub";
    TRANSFORMERS_CACHE = "/data/hf-cache";
  };
}
