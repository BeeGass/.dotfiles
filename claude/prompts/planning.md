# Planning

Make the plan **fully self-contained** — every piece of context needed to execute the plan must be present in the plan itself. Specifically:

## Context and References
- List all contextual files, links, documentation, and resources that inform the plan. Include full file paths and URLs.
- Summarize the relevant content from each reference so the plan can be understood without opening them.

## File Changes
- For each **existing file** being modified, use this format:

  ````
  ### Modified File: <filename>

  **Path**: `<full absolute file path>`
  **Purpose**: <What is being changed and why.>
  **Sub-agent**: <Agent assignment and wave/phase>

  ```diff
  <unified diff showing the exact changes>
  ```
  ````

  The diff must be a **unified diff** with enough surrounding context lines to unambiguously locate each hunk. Every change must be shown — no "rest of file unchanged" elisions.
- For each **new file** being created, use this format:

  ````
  ### New File: <filename>

  **Path**: `<full absolute file path>`
  **Purpose**: <What the file does, what it replaces or introduces, and how it fits into the existing structure.>
  **Sub-agent**: <Agent assignment and wave/phase>

  ```<language>
  <complete intended contents of the file>
  ```
  ````

  The fenced code block must contain the **complete** file contents — no placeholders, no "fill in later" stubs.

## Test-Driven Development
- Invoke the `/test-driven-development` skill for all TDD work. Every test phase must be executed through this skill.
- Define tests *before* the implementation they validate.
- Each feature or change must have corresponding test cases written first.
- Specify the test framework, test file paths, and expected assertions.

## Sub-Agent Assignments
- Annotate every task and sub-task with which sub-agent is responsible for it.
- Group tasks by sub-agent so parallelizable work is clearly identified.
- Mark dependencies between sub-agent tasks explicitly (e.g., "blocked by Agent A completing task 2").

## Plan Phases
Structure the plan into ordered phases. At minimum include:
1. **Research/Context Gathering** — read and summarize all relevant files and references.
2. **Test Scaffolding** — write failing tests for all planned changes.
3. **Implementation** — make the code changes to pass the tests.
4. **Verification** — run full test suite, linting, and type checking.
5. **Documentation and Changelog** — update all relevant docs (README, API docs, inline comments) and add a changelog entry describing what changed and why.

---

- ~/.claude-alt/plans/tmp-claude-response-md-we-are-quirky-sunset.md
- ~/.claude-alt/plans/async-doodling-sedgewick.md
- ~/.claude-alt/plans/tmp-claude-response-md-we-are-synchronous-stardust.md
- ~/.claude-alt/plans/tmp-claude-response-md-we-are-fancy-candle.md
-

---

oh please update the plan to abide by:

`````md
Make the plan **fully self-contained** — every piece of context needed to execute the plan must be present in the plan itself. Specifically:

## Context and References
- List all contextual files, links, documentation, and resources that inform the plan. Include full file paths and URLs.
- Summarize the relevant content from each reference so the plan can be understood without opening them.

## File Changes
- For each **existing file** being modified, use this format:

  ````
  ### Modified File: <filename>

  **Path**: `<full absolute file path>`
  **Purpose**: <What is being changed and why.>
  **Sub-agent**: <Agent assignment and wave/phase>

  ```diff
  <unified diff showing the exact changes>
  ```
  ````

  The diff must be a **unified diff** with enough surrounding context lines to unambiguously locate each hunk. Every change must be shown — no "rest of file unchanged" elisions.
- For each **new file** being created, use this format:

  ````
  ### New File: <filename>

  **Path**: `<full absolute file path>`
  **Purpose**: <What the file does, what it replaces or introduces, and how it fits into the existing structure.>
  **Sub-agent**: <Agent assignment and wave/phase>

  ```<language>
  <complete intended contents of the file>
  ```
  ````

  The fenced code block must contain the **complete** file contents — no placeholders, no "fill in later" stubs.

## Test-Driven Development
- Invoke the `/test-driven-development` skill for all TDD work. Every test phase must be executed through this skill.
- Define tests *before* the implementation they validate.
- Each feature or change must have corresponding test cases written first.
- Specify the test framework, test file paths, and expected assertions.

## Sub-Agent Assignments
- Annotate every task and sub-task with which sub-agent is responsible for it.
- Group tasks by sub-agent so parallelizable work is clearly identified.
- Mark dependencies between sub-agent tasks explicitly (e.g., "blocked by Agent A completing task 2").

## Plan Phases
Structure the plan into ordered phases. At minimum include:
1. **Research/Context Gathering** — read and summarize all relevant files and references.
2. **Test Scaffolding** — write failing tests for all planned changes.
3. **Implementation** — make the code changes to pass the tests.
4. **Verification** — run full test suite, linting, and type checking.
5. **Documentation and Changelog** — update all relevant docs (README, API docs, inline comments) and add a changelog entry describing what changed and why.
`````

---

  You are working in `/home/beegass/Projects/FreeCtrl/refactor-synapse-composable-framework`.

  Read repo guidance first:
  - `AGENTS.md`
  - `./.codex/AGENTS.md` if present
  - relevant `.claude/` docs only as reference, do not modify Claude files.

  Goal:
  Continue the Pallas correctness/performance work started for text PM kernels, but now apply the same rigor to the other SSM families and observation layers.

  Important naming note:
  `libs/zoo/zoo/_src/models/text/pm/ssm/unary/{jax,pallas}/linear/` is a misnomer. It is really the O(1) generation/constant-state path and should eventually be named something like:
  - `libs/zoo/zoo/_src/models/text/pm/ssm/unary/{jax,pallas}/constant/`

  Do not do a disruptive rename blindly. If renaming, introduce compatibility shims or update dispatch/tests carefully so existing imports keep working during migration. Prefer proving correctness/
  performance first, then do naming cleanup as a separate, well-tested step.

  Target families:
  - SSM:
    - `unary`
    - `bilinear_single_input`
    - `bilinear_dual_input`
    - `bilinear_dual_input_state`
    - `bilinear_static_gated`
    - `contrast_single`
    - `contrast_double`
  - Observation:
    - `first_order`
    - `second_order`
    - `second_order_split`

  Target paths:
  - `libs/zoo/zoo/_src/models/text/pm/ssm/**/{jax,pallas}/`
  - `libs/zoo/zoo/_src/models/text/pm/obs/**/{jax,pallas}/`
  - `tests/libs/test-zoo/models/text/pm/benchmarks/`
  - `tests/libs/test-zoo/models/text/pm/kernels/`

  Context from prior unary work:
  - Unary Pallas had broken head-dim alignment for `head_dim=64`; Pallas blocks needed padded head dims aligned to 128.
  - Tail padding must be masked, not treated as real sequence steps. Inactive tail positions should not update state or accumulate gradients.
  - VJP/backward must include final-state cotangent correctly.
  - Explicit JAX backward can be wrong too. For unary, the `Lambda_1` transpose contraction in JAX explicit backward was inconsistent with autodiff.
  - Avoid `int()`, `float()`, `.item()`, or similar casts on values that may be JAX arrays/tracers; those can force device-to-host transfers or break tracing.
  - GPU benchmark workers should use:
    - `XLA_PYTHON_CLIENT_PREALLOCATE=false`
    - `XLA_FLAGS=--xla_gpu_enable_command_buffer=`
  - Do not run multiple GPU benchmark workers concurrently; previous concurrent runs caused false CUDA graph OOM.

  Autotuning direction:
  - The repo already has `zoo._src.ops.pallas.autotune.autotune_kernel`, which uses `from tune_jax import tune` and caches JSON results by kernel/GPU/shapes/dtype.
  - Desired behavior: explicit `chunk_size`, `num_warps`, `num_stages` should override tuning, but `None` should mean “autotune this”.
  - Tests/benchmarks should be able to exercise tuned parameters, preferably by passing `None` for Pallas tunables.
  - Cache tuning results so subsequent benchmark/test runs avoid repeated compile/search cost.
  - Validate current `autotune.py` behavior before expanding it. There may be partial unverified edits in the current worktree around `None` semantics.

  Work plan:
  1. Inspect current git diff and do not overwrite unrelated user changes.
  2. Run targeted static checks on currently modified PM/Pallas/autotune files.
  3. Inventory each SSM/OBS family’s JAX and Pallas forward/backward/VJP surfaces.
  4. For each family, build small correctness tests:
     - Forward Pallas vs JAX.
     - Explicit JAX backward vs `jax.grad` of JAX forward.
     - Pallas VJP vs corrected JAX/autodiff.
     - Include non-multiple sequence lengths and `head_dim=64` to catch Pallas alignment issues.
     - Include final-state loss terms so final-state cotangent is tested.
  5. Fix benchmark input layout issues before trusting matrix results. Previous interrupted full matrix showed many non-unary JAX workers failing due missing args or layout mismatches.
  6. For Pallas kernels:
     - Share helpers for alignment, tail masks, dtype resolution, and Pallas lowering config where possible.
     - Prefer minimal, maintainable kernel changes over clever rewrites.
     - Keep public API compatibility.
  7. Add or repair benchmark reporting:
     - Separate runtime status from correctness status.
     - Use allclose-style correctness gating, not raw max-relative alone near zero.
     - Report max abs/rel error, memory delta, peak memory, compile time, mean time.
  8. Run verification in layers:
     - `uv run ruff check ...`
     - `uv run ty check ...`
     - `uv run python -m compileall ...`
     - Focused correctness tests per family.
     - Benchmark worker smoke tests per repaired family/surface.
     - Full matrix only after focused tests pass.

  Useful commands:
  ```bash
  env XLA_PYTHON_CLIENT_PREALLOCATE=false XLA_FLAGS=--xla_gpu_enable_command_buffer= \
    uv run pytest tests/libs/test-zoo/models/text/pm/kernels -q

  env XLA_PYTHON_CLIENT_PREALLOCATE=false XLA_FLAGS=--xla_gpu_enable_command_buffer= \
    uv run python tests/libs/test-zoo/models/text/pm/benchmarks/_gpu_benchmark_matrix.py \
    --family unary --mode chunked --variant - --backend pallas --surface fwd \
    --output /tmp/pm_unary_chunked_pallas_fwd.json

  Deliverables:

  - Correctness fixes for Pallas and, where needed, explicit JAX backward references.
  - Focused tests for SSM and OBS families.
  - Benchmark harness fixes so the matrix uses valid inputs for every family.
  - Tuned/cached Pallas hyperparameter path where None means autotune.
  - A concise summary of which families/surfaces are correct, which are faster/slower than JAX, and which remain blocked.

  ---

now please finish:
```
Remaining work (deferred)

- Wave 4 FP8 support (Agent D) — 12 xfailed.
- Wave 5A/5B perf polish + Pallas-vs-JAX gate test harness.
- Wave 6 docs + changelog.
- Tighten the in-kernel precision so TestJaxGradParity passes vs pure-autodiff ground truth (not vs the known-buggy JAX reference kernel).
- Throughput vjp path has a tuple-unpack edge case under jax.grad composition — isolated issue.
```
