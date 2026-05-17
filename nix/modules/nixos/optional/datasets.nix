# Dataset / ML cache layout across the multi-drive layout from
# docs/nixos/manifold-install-plan.md.
#
# Capacity-by-tier rationale:
#   /data      Crucial T705 4 TB (PCIe 5.0)  -- datasets, HF cache, corpora
#   /models    SN850X 2 TB (PCIe 4.0, bind)  -- model weights (HF, ollama, etc.)
#   /checkpoints SN850X 2 TB (PCIe 4.0, bind) -- training run + sweep outputs
#   /work      Samsung 980 1 TB (PCIe 3.0)   -- containers, VMs, builds, scratch
#   /rescue    750 EVO 250 GB (SATA)         -- ISOs, transfer staging
#
# Each tmpfiles rule has `nofail` semantics: if the target mount isn't
# present (drive missing, label mismatch), the missing parent prevents the
# nested directory from landing on /. Still: verify mounts post-boot with
# `df -h /data /srv/ml /work /rescue` before assuming the layout took.
{ vars, ... }:
let
  u = vars.username;
in
{
  systemd.tmpfiles.rules = [
    # /data (T705 4 TB XFS) -- datasets, HF cache, corpora, benchmarks
    "d /data                0755 ${u} users -"
    "d /data/datasets       0755 ${u} users -"
    "d /data/hf-cache       0755 ${u} users -"
    "d /data/hf-cache/hub   0755 ${u} users -"
    "d /data/tokenized      0755 ${u} users -"
    "d /data/corpora        0755 ${u} users -"
    "d /data/benchmarks     0755 ${u} users -"

    # /models (SN850X bind from /srv/ml/models) -- model weights
    "d /models                          0755 ${u} users -"
    "d /models/hf                       0755 ${u} users -"
    "d /models/ollama                   0755 ${u} users -"
    "d /models/llama.cpp                0755 ${u} users -"
    "d /models/vllm                     0755 ${u} users -"
    "d /models/checkpoints-imported     0755 ${u} users -"

    # /checkpoints (SN850X bind from /srv/ml/checkpoints) -- training outputs
    "d /checkpoints          0755 ${u} users -"
    "d /checkpoints/runs     0755 ${u} users -"
    "d /checkpoints/sweeps   0755 ${u} users -"
    "d /checkpoints/manual   0755 ${u} users -"

    # /work (Samsung 980 1 TB XFS) -- containers, VMs, builds, scratch
    "d /work                 0755 root     root  -"
    "d /work/docker          0711 root     root  -"
    "d /work/containers      0711 root     root  -"
    "d /work/vms             0755 ${u}     users -"
    "d /work/build           0755 ${u}     users -"
    "d /work/scratch         0755 ${u}     users -"
    "d /work/downloads       0755 ${u}     users -"
    "d /work/staging         0755 ${u}     users -"
    "d /work/cache           0755 ${u}     users -"

    # /rescue (750 EVO 250 GB ext4) -- ISOs, ad-hoc staging
    "d /rescue               0755 root     root  -"
    "d /rescue/isos          0755 ${u}     users -"
    "d /rescue/staging       0755 ${u}     users -"
  ];

  environment.sessionVariables = {
    # Hugging Face caches stay on /data (large, growable, datasets-adjacent)
    HF_HOME = "/data/hf-cache";
    HF_HUB_CACHE = "/data/hf-cache/hub";
    TRANSFORMERS_CACHE = "/data/hf-cache";

    # Roots advertised to tooling
    DATASETS_ROOT = "/data/datasets";
    MODELS_ROOT = "/models";
    CHECKPOINTS_ROOT = "/checkpoints";
    SCRATCH_ROOT = "/work/scratch";
  };
}
