# Storage layout: /library, /work, /cache, /pad.
#
# Mounted by nix/hosts/manifold/hardware-configuration.nix (label-based).
# This module owns the policy on top of those mounts:
#   - systemd-tmpfiles rules for the subtree the user expects to find
#   - environment.sessionVariables that point ML tooling at the right roots
#
# Semantic model:
#   /library = read-mostly reference (datasets, HF cache, external models)
#   /work    = active outputs       (runs, checkpoints, logs, projects)
#   /cache   = rebuildable          (docker, uv, pip, triton, jax, ccache)
#   /pad     = scratchpad           (ideas, scripts, probes, snippets)
#
# Module name is `datasets` for historical reasons; the semantic scope is
# broader now. Role wiring (flake.nix manifold roles) still uses "datasets".
#
# Each tmpfiles rule has implicit-nofail semantics: if a parent mount isn't
# present (drive missing, label mismatch), the missing parent prevents the
# nested directory from landing on /. Still: verify mounts post-boot with
# `df -h /library /work /cache /pad` before assuming the layout took.
{ vars, ... }:
let
  u = vars.username;
in
{
  systemd.tmpfiles.rules = [
    # /library (T705 4 TB btrfs zstd:1) -- read-mostly reference
    "d /library                         0755 ${u} users -"
    "d /library/datasets                0755 ${u} users -"
    "d /library/hf-cache                0755 ${u} users -"
    "d /library/hf-cache/hub            0755 ${u} users -"
    "d /library/corpora                 0755 ${u} users -"
    "d /library/tokenized               0755 ${u} users -"
    "d /library/benchmarks              0755 ${u} users -"
    "d /library/models-external         0755 ${u} users -"
    "d /library/models-local-promoted   0755 ${u} users -"
    "d /library/reference               0755 ${u} users -"

    # /work (SN850X 2 TB btrfs zstd:1) -- active outputs
    "d /work                            0755 ${u} users -"
    "d /work/runs                       0755 ${u} users -"
    "d /work/checkpoints                0755 ${u} users -"
    "d /work/logs                       0755 ${u} users -"
    "d /work/notes                      0755 ${u} users -"
    "d /work/reports                    0755 ${u} users -"
    "d /work/samples                    0755 ${u} users -"
    "d /work/lineages                   0755 ${u} users -"
    "d /work/projects                   0755 ${u} users -"

    # /cache (980 1 TB btrfs zstd:1) -- rebuildable tool caches
    "d /cache                           0755 root    root  -"
    "d /cache/docker                    0711 root    root  -"
    "d /cache/containers                0711 root    root  -"
    "d /cache/uv                        0755 ${u}    users -"
    "d /cache/pip                       0755 ${u}    users -"
    "d /cache/cargo                     0755 ${u}    users -"
    "d /cache/ccache                    0755 ${u}    users -"
    "d /cache/triton                    0755 ${u}    users -"
    "d /cache/jax                       0755 ${u}    users -"
    "d /cache/tmp                       0755 ${u}    users -"
    "d /cache/downloads                 0755 ${u}    users -"
    "d /cache/preprocess                0755 ${u}    users -"

    # /pad (750 EVO 250 GB ext4) -- scratchpad
    "d /pad                             0755 ${u} users -"
    "d /pad/ideas                       0755 ${u} users -"
    "d /pad/scripts                     0755 ${u} users -"
    "d /pad/probes                      0755 ${u} users -"
    "d /pad/loose-logs                  0755 ${u} users -"
    "d /pad/snippets                    0755 ${u} users -"
    "d /pad/inbox                       0755 ${u} users -"
  ];

  environment.sessionVariables = {
    # /library -- read-mostly reference
    LIBRARY_ROOT = "/library";
    DATASETS_ROOT = "/library/datasets";
    HF_HOME = "/library/hf-cache";
    HF_HUB_CACHE = "/library/hf-cache/hub";
    TRANSFORMERS_CACHE = "/library/hf-cache";
    MODELS_ROOT = "/library/models-external";

    # /work -- active outputs
    WORK_ROOT = "/work";
    RUNS_ROOT = "/work/runs";
    CHECKPOINTS_ROOT = "/work/checkpoints";

    # /cache -- rebuildable tool caches
    CACHE_ROOT = "/cache";
    UV_CACHE_DIR = "/cache/uv";
    PIP_CACHE_DIR = "/cache/pip";
    TRITON_CACHE_DIR = "/cache/triton";
    JAX_COMPILATION_CACHE_DIR = "/cache/jax";

    # /pad -- scratchpad
    PAD_ROOT = "/pad";
  };
}
