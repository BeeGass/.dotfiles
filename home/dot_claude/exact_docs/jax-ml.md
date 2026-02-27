# JAX/Flax ML Conventions

Comprehensive JAX ecosystem guide covering Flax NNX, Optax, Orbax, Grain, Tunix, and Fiddle.

---

## 1. JAX Principles

- **Functional programming**: Pure functions, no side effects in jitted code
- **Immutable arrays**: JAX arrays are immutable, use `.at[]` for updates
- **JIT compilation**: Use `@jax.jit` for performance-critical code
- **Vectorization**: Use `jax.vmap` for batch operations, `jax.pmap` for multi-device parallelism
- **Automatic differentiation**: Design with `jax.grad` and `jax.value_and_grad` in mind
- **PRNGKey management**: Explicit random keys via `jax.random.key()`, always split keys properly
- **Transformations compose**: JAX transformations (jit, grad, vmap, pmap) compose seamlessly

---

## 2. Array Type Annotations

**Use jaxtyping for all array-valued functions:**

```python
from jaxtyping import Array, Float, Int, PRNGKeyArray, jaxtyped
from typeguard import typechecked

@jaxtyped(typechecker=typechecked)
def attention(
    query: Float[Array, "batch seq_len d_model"],
    key: Float[Array, "batch seq_len d_model"],
    value: Float[Array, "batch seq_len d_model"],
    mask: Int[Array, "batch seq_len seq_len"] | None = None,
) -> Float[Array, "batch seq_len d_model"]:
    """Compute scaled dot-product attention.

    Args:
        query: Query vectors with shape (batch, seq_len, d_model).
        key: Key vectors with shape (batch, seq_len, d_model).
        value: Value vectors with shape (batch, seq_len, d_model).
        mask: Optional attention mask (0 = attend, 1 = mask).

    Returns:
        Attention output with shape (batch, seq_len, d_model).

    Example:
        >>> q = jnp.ones((2, 10, 512))
        >>> out = attention(q, q, q)
        >>> out.shape
        (2, 10, 512)
    """
    ...
```

**Shape Naming Conventions:**
- `batch` or `b` for batch dimension
- `seq_len` or `seq` for sequence length
- `d_model`, `d_head`, `d_ff` for model dimensions
- `height` or `h`, `width` or `w`, `channels` or `c` for images
- `num_gpu` or `n_gpu` for device parallelism
- `batch_per_gpu` for sharded batch

**Multi-GPU Shape Convention:**
```python
@jaxtyped(typechecker=typechecked)
def distributed_forward(
    x: Float[Array, "num_gpu batch_per_gpu seq_len d_model"],
    params: Float[Array, "d_model d_ff"],
) -> Float[Array, "num_gpu batch_per_gpu seq_len d_ff"]:
    """Forward pass with leading GPU dimension."""
    ...
```

---

## 3. Precision Policy

**Default: bfloat16 for computation, float32 for numerically sensitive ops**

```python
from jax import numpy as jnp

def init_params(key: PRNGKeyArray, d_model: int) -> Float[Array, "d_model d_model"]:
    """Initialize parameters in float32, cast to bfloat16.

    Example:
        >>> key = jax.random.PRNGKey(0)
        >>> params = init_params(key, 512)
        >>> params.dtype
        dtype('bfloat16')
    """
    # Initialize in float32 for numerical stability
    params_f32 = jax.random.normal(key, (d_model, d_model), dtype=jnp.float32)
    params_f32 = params_f32 / jnp.sqrt(d_model)

    # Cast to bfloat16 for training
    return params_f32.astype(jnp.bfloat16)

# Config
class ModelConfig(BaseModel):
    """Model configuration with precision policy."""
    param_dtype: str = Field(default="bfloat16", description="Parameter dtype")
    compute_dtype: str = Field(default="bfloat16", description="Computation dtype")
    accumulator_dtype: str = Field(default="float32", description="Gradient accumulator")

    model_config = {"frozen": True}
```

**When to use float32:**
- Loss computation and gradients accumulation
- Numerical stability-sensitive ops (softmax, layer norm, loss scales)
- Small models where precision matters more than speed

**When to use bfloat16:**
- Default for all parameters and activations
- Matrix multiplications (einsum, matmul)
- Attention scores (after scaling)

---

## 4. Sharding and Mesh

**Default mesh: (model, data)**

```python
from jax.experimental import mesh_utils
from jax.sharding import Mesh, NamedSharding, PartitionSpec as P

def create_mesh(num_devices: int) -> Mesh:
    """Create default (model, data) mesh.

    Example:
        >>> mesh = create_mesh(8)
        >>> mesh.shape
        {'model': 1, 'data': 8}
    """
    devices = mesh_utils.create_device_mesh((1, num_devices))
    return Mesh(devices, axis_names=("model", "data"))

def get_sharding_spec(
    mesh: Mesh,
    spec: tuple[str | None, ...],
) -> NamedSharding:
    """Create NamedSharding from partition spec."""
    return NamedSharding(mesh, P(*spec))

# Shard batch dimension across data axis
def shard_data(
    batch: Float[Array, "batch seq_len d_model"],
    mesh: Mesh,
) -> Float[Array, "batch seq_len d_model"]:
    sharding = get_sharding_spec(mesh, ("data", None, None))
    return jax.device_put(batch, sharding)

# Shard parameters across model axis
def shard_params(
    params: Float[Array, "d_model d_ff"],
    mesh: Mesh,
) -> Float[Array, "d_model d_ff"]:
    sharding = get_sharding_spec(mesh, (None, "model"))
    return jax.device_put(params, sharding)
```

---

## 5. Shape Conventions

**Standard shapes (always in this order):**

```python
# Sequences (NLP, time series)
tokens: Float[Array, "batch seq_len d_model"]
attention_output: Float[Array, "batch seq_len d_model"]

# Images
images: Float[Array, "batch height width channels"]
# NOT (batch, channels, height, width) - avoid PyTorch convention

# Multi-GPU sequences
distributed_tokens: Float[Array, "num_gpu batch_per_gpu seq_len d_model"]

# Attention patterns
attention_weights: Float[Array, "batch num_heads seq_len seq_len"]

# Embeddings
token_embeddings: Float[Array, "vocab_size d_model"]
position_embeddings: Float[Array, "max_seq_len d_model"]
```

---

## 6. einsum Preference

**Use einsum for clarity and performance:**

```python
@jaxtyped(typechecker=typechecked)
def linear_transform(
    x: Float[Array, "batch seq_len d_in"],
    w: Float[Array, "d_in d_out"],
) -> Float[Array, "batch seq_len d_out"]:
    """Linear transformation using einsum."""
    # Prefer einsum over @ or matmul for explicitness
    return jnp.einsum("bsi,io->bso", x, w)

@jaxtyped(typechecker=typechecked)
def attention_scores(
    q: Float[Array, "batch num_heads seq_len d_head"],
    k: Float[Array, "batch num_heads seq_len d_head"],
) -> Float[Array, "batch num_heads seq_len seq_len"]:
    """Compute attention scores with einsum."""
    # Clear dimension names in einsum
    # b=batch, h=heads, i=query_seq, j=key_seq, d=d_head
    return jnp.einsum("bhid,bhjd->bhij", q, k)
```

**When NOT to use einsum:**
- Simple element-wise ops: use `*` directly
- Single matrix multiply with clear semantics: `@` is fine
- Broadcasting that's clearer with explicit reshape

---

## 7. PRNGKey Threading

**Always thread keys explicitly, never reuse:**

```python
@jaxtyped(typechecker=typechecked)
def init_layer(
    key: PRNGKeyArray,
    d_in: int,
    d_out: int,
) -> tuple[Float[Array, "d_in d_out"], Float[Array, "d_out"]]:
    """Initialize layer with proper key splitting."""
    # Split key for independent randomness
    key_w, key_b = jax.random.split(key, 2)

    # Initialize in float32
    w = jax.random.normal(key_w, (d_in, d_out), dtype=jnp.float32)
    w = w / jnp.sqrt(d_in)  # Xavier init

    b = jax.random.normal(key_b, (d_out,), dtype=jnp.float32) * 0.01

    # Cast to bfloat16
    return w.astype(jnp.bfloat16), b.astype(jnp.bfloat16)

def init_model(key: PRNGKeyArray, config: ModelConfig) -> dict[str, Array]:
    """Initialize full model with proper key threading."""
    params = {}

    # Split key for each layer
    keys = jax.random.split(key, config.num_layers)

    for i, layer_key in enumerate(keys):
        w, b = init_layer(layer_key, config.d_model, config.d_ff)
        params[f"layer_{i}_w"] = w
        params[f"layer_{i}_b"] = b

    return params
```

---

## 8. Transformation Rules

**jit, vmap, grad usage:**

```python
from functools import partial

# jit: use for performance-critical functions
@partial(jax.jit, static_argnames=("d_model",))
@jaxtyped(typechecker=typechecked)
def forward_pass(
    params: dict[str, Array],
    x: Float[Array, "batch seq_len d_model"],
    d_model: int,  # static
) -> Float[Array, "batch seq_len d_model"]:
    """JIT-compiled forward pass.

    Note:
        First call incurs compilation overhead (~seconds).
        Subsequent calls are fast.
    """
    # No Python control flow (if/for) inside jit
    # Use jax.lax.cond, jax.lax.scan instead
    ...

# vmap: vectorize over batch dimension
@jaxtyped(typechecker=typechecked)
def single_example_loss(
    pred: Float[Array, "seq_len vocab_size"],
    target: Int[Array, "seq_len"],
) -> Float[Array, ""]:
    """Compute loss for single example."""
    return -jnp.sum(jax.nn.log_softmax(pred) * jax.nn.one_hot(target, pred.shape[-1]))

# Vectorize to handle batch
batched_loss = jax.vmap(single_example_loss)

# grad: use value_and_grad for efficiency
@jax.jit
def train_step(
    params: dict[str, Array],
    opt_state: Any,
    batch: Float[Array, "batch seq_len d_model"],
    targets: Int[Array, "batch seq_len"],
) -> tuple[dict[str, Array], Any, Float[Array, ""]]:
    """Single training step with gradient computation."""
    def loss_fn(p):
        preds = forward_pass(p, batch, d_model=batch.shape[-1])
        return jnp.mean(compute_loss(preds, targets))

    # Compute loss and gradients in one pass
    loss, grads = jax.value_and_grad(loss_fn)(params)

    # Update params
    updates, opt_state = optimizer.update(grads, opt_state)
    params = optax.apply_updates(params, updates)

    return params, opt_state, loss
```

---

## 9. Safety Checks

**Mandatory checks for numerical stability:**

```python
@jaxtyped(typechecker=typechecked)
def safe_softmax(
    logits: Float[Array, "batch seq_len vocab_size"],
) -> Result[Float[Array, "batch seq_len vocab_size"], NumericalError]:
    """Numerically stable softmax with safety checks."""
    # Check for NaN/Inf in inputs
    if jnp.any(jnp.isnan(logits)) or jnp.any(jnp.isinf(logits)):
        return Err(
            NumericalError(
                operation="softmax",
                reason="NaN or Inf in input logits",
                context={
                    "nan_count": jnp.sum(jnp.isnan(logits)).item(),
                    "inf_count": jnp.sum(jnp.isinf(logits)).item(),
                },
            )
        )

    # Stable softmax: subtract max for numerical stability
    logits_max = jnp.max(logits, axis=-1, keepdims=True)
    logits_shifted = logits - logits_max

    # Compute in float32 for stability
    logits_f32 = logits_shifted.astype(jnp.float32)
    probs_f32 = jax.nn.softmax(logits_f32, axis=-1)

    # Cast back to bfloat16
    probs = probs_f32.astype(jnp.bfloat16)

    return Ok(probs)

@jaxtyped(typechecker=typechecked)
def check_gradient_norms(
    grads: dict[str, Array],
    threshold: float = 100.0,
) -> Result[None, NumericalError]:
    """Check gradient norms for exploding gradients."""
    max_norm = 0.0
    problem_param = None

    for name, grad in grads.items():
        norm = jnp.linalg.norm(grad.flatten())
        if norm > max_norm:
            max_norm = norm
            problem_param = name

        if jnp.isnan(norm) or jnp.isinf(norm):
            return Err(
                NumericalError(
                    operation="gradient_check",
                    reason=f"NaN or Inf gradient in {name}",
                )
            )

    if max_norm > threshold:
        return Err(
            NumericalError(
                operation="gradient_check",
                reason="Exploding gradient detected",
                context={"max_norm": max_norm, "param_name": problem_param},
            )
        )

    return Ok(None)
```

---

## 10. Flax NNX

**NNX is the standard**: Use Flax NNX (third-generation API), not deprecated Linen.

- **PyGraph-based**: NNX uses PyGraphs (not PyTrees), enabling reference sharing and mutability
- **Pythonic objects**: Models are regular Python objects, similar to PyTorch's approach
- **Module composition**: Build models from composable `nnx.Module` subclasses
- **State management**: NNX handles mutable state naturally
- **Initialization**: Use `nnx.Rngs` for deterministic initialization
- **Sequential models**: Use `nnx.Sequential` for linear layer stacking

---

## 11. Optax (Optimization)

- **Gradient processing**: DeepMind's library for gradient transformations
- **Composable optimizers**: Chain gradient transformations to create custom optimizers
- **Popular optimizers**: Adam, AdamW, SGD, RMSProp, Lion, etc.
- **Learning rate schedules**: Use optax schedules (cosine decay, warmup, polynomial)
- **Gradient clipping**: Use `optax.clip_by_global_norm()` to prevent exploding gradients
- **Modular design**: Combine low-level transformations (`scale_by_adam`, `add_decayed_weights`)

---

## 12. Orbax (Checkpointing)

- **Standard checkpointing**: Recommended checkpointing library for JAX
- **Asynchronous saving**: Non-blocking checkpoint saves for better performance
- **Multi-host support**: Efficient checkpointing across distributed training
- **Type handlers**: Supports various data types (PyTrees, arrays, custom types)
- **Checkpoint management**: Built-in rotation and retention policies
- **Use with NNX**: `orbax.checkpoint.PyTreeCheckpointer` works with NNX models

---

## 13. Grain (Data Loading)

- **JAX-native data loading**: Google's performant, deterministic data loading library
- **Philosophy**: Performance, reproducibility, and flexibility
- **Random access**: Efficient random access enables on-the-fly shuffling
- **Deterministic**: Reproducible data ordering, resilient to preemption
- **ArrayRecord integration**: Works with Google's ArrayRecord format
- **Used in production**: Powers MaxText, Gemma, and many Google projects

---

## 14. Tunix (LLM Post-Training)

- **LLM fine-tuning**: JAX-native library for LLM post-training and alignment
- **Supervised Fine-Tuning (SFT)**: Fine-tune pre-trained models on specific tasks
- **Reinforcement Learning**: Supports PPO, GRPO, GSPO for RL-based alignment
- **Direct Preference Optimization (DPO)**: Align models with human preferences
- **Model Distillation**: Compress large models into smaller, faster ones
- **TPU-optimized**: Designed for optimal performance on TPUs

---

## 15. Fiddle (Configuration Management)

- **Python-first configs**: Google's configuration library for ML experiments
- **Deep configurability**: Configure complex parameter hierarchies in readable Python
- **Type-safe**: Better than YAML/JSON for catching config errors early
- **ML-focused**: Particularly well-suited for ML applications with many hyperparameters

---

## 16. Training Best Practices

- **Reproducibility**: Set random seeds (`jax.random.key(seed)`), document all hyperparameters
- **Gradient clipping**: Use `optax.clip_by_global_norm()` to prevent instability
- **Learning rate schedules**: Use optax schedules with warmup for better convergence
- **Metrics tracking**: Log training/validation metrics regularly (wandb, tensorboard)
- **Validation sets**: Always validate on held-out data, use proper train/val/test splits
- **Checkpoint frequently**: Use Orbax to save checkpoints during training
- **Monitor gradients**: Track gradient norms to detect training issues early
- **Mixed precision training**: Use bfloat16 for memory savings and speed

---

## 17. Code Organization for ML

- **Separate concerns**: Models (nnx modules), training loops, data loading (grain), evaluation
- **Config with Fiddle**: Use Fiddle for experiment configuration instead of YAML/JSON
- **Experiment tracking**: Log experiments with wandb, tensorboard, or similar
- **Reproducible environments**: Pin dependency versions (use uv)
- **Modular training loops**: Separate training step, evaluation step, checkpoint logic
- **Unit test transformations**: Test model transformations independently before full training

---

## 18. CI Linter Checklist for JAX

```
[ ] All array-valued functions use jaxtyping annotations
[ ] Shape annotations match conventions: (batch, seq_len, ...) or (batch, ..., h, w, c)
[ ] Multi-GPU arrays have leading num_gpu dimension
[ ] Parameters initialized in float32, cast to bfloat16
[ ] PRNGKey never reused (always split)
[ ] jit functions mark static arguments with static_argnames
[ ] No Python control flow (if/for) inside jit without lax alternatives
[ ] einsum used for multi-dimensional contractions
[ ] Sharding uses (model, data) mesh convention
[ ] NaN/Inf checks present in numerically sensitive operations
[ ] Gradient norm checks in training loop
[ ] chex.assert_shape used for critical dimension validation
```
