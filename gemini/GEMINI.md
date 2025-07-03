# Gemini CLI Configuration for BeeGass

<!-- Import permissions configuration -->
<!-- @import ../claude/PERMISSIONS.md -->

## Project Conventions

### Python Development Stack
- **Package Manager**: UV (exclusively)
- **ML Framework**: JAX/Flax/NNX ecosystem
- **Type Checking**: jaxtyping for array shapes, strict mypy/pyright
- **Linting**: Ruff (exclusively)
- **Python Version**: 3.11+ preferred

### Git Workflow
```
main         # Production-ready code only
├── dev-main # Testing bed, only branch merged into main
└── dev-*    # Feature development branches
└── test-*   # Experimental/testing branches
```

### Code Quality Standards
1. **Type Annotations**: ALWAYS required
   - Use `jaxtyping` for JAX arrays: `Float[Array, "batch dim"]`
   - Explicit return types for all functions
   - No `Any` types without justification

2. **Documentation**:
   - Comprehensive docstrings for ALL functions/classes
   - Include LaTeX for mathematical concepts
   - Example usage in docstrings
   - Clear parameter/return descriptions

3. **Code Structure**:
   - Modular, reusable components
   - Hierarchical organization (loose guideline)
   - Clear separation of concerns
   - Functional programming patterns preferred in JAX

## Common Commands

### Python/UV Commands
```bash
# Project setup
uvnew <project-name> <python-version>  # Create new UV project
uvsetup                                 # Sync deps and activate venv
uvupgrade                              # Upgrade all dependencies

# Development
uv sync --all-extras                   # Sync with all optional deps
uv run python <script>                 # Run with UV environment
uv pip install -e ".[dev]"             # Install in editable mode
```

### Type Checking & Linting
```bash
# Type checking
uv run mypy src/ --strict
uv run pyright src/
uv run jaxtyping --enable-runtime-typechecking

# Linting & Formatting
uv run ruff check src/
uv run ruff format src/

# Pre-commit checks
uv run pre-commit run --all-files
```

### JAX/Flax/NNX Specific
```bash
# JAX debugging (use sparingly, only when debugging)
# JAX_DEBUG_NANS=True - Checks for NaN values in computations
# JAX_DISABLE_JIT=True - Disables JIT compilation for debugging
# JAX_LOG_COMPILES=True - Logs when functions are being compiled

# Memory profiling
uv run python -m jax.profiler.profiler script.py
```

### Testing
```bash
# Run tests
uv run pytest tests/ -v
uv run pytest tests/ -v --cov=src --cov-report=html

# Run specific test
uv run pytest tests/test_module.py::test_function -v
```

## Project Structure Template
```
project/
├── src/
│   └── project_name/
│       ├── __init__.py
│       ├── models/       # NNX model definitions
│       ├── data/         # Data loading/processing
│       ├── training/     # Training loops
│       ├── utils/        # Utility functions
│       └── types.py      # Custom type definitions
├── tests/
│   └── test_*.py
├── docs/                 # Documentation directory (REQUIRED)
│   ├── api/             # API documentation
│   ├── tutorials/       # Tutorial notebooks/markdown
│   └── design.md        # Design decisions and architecture
├── pyproject.toml        # UV configuration
├── .pre-commit-config.yaml
└── README.md
```

## JAX/Flax/NNX Best Practices

### Type Annotations with jaxtyping
```python
from jaxtyping import Array, Float, Int, PRNGKeyArray
from typing import TypeAlias

# Define reusable type aliases
Batch: TypeAlias = Float[Array, "batch ..."]
Image: TypeAlias = Float[Array, "height width channels"]
Logits: TypeAlias = Float[Array, "batch classes"]
```

### NNX Module Pattern
```python
import flax.nnx as nn
from jaxtyping import Float, Array

class MyModule(nn.Module):
    """Description of module functionality.
    
    Mathematical formulation:
    .. math::
        y = \sigma(Wx + b)
    
    Args:
        features: Number of output features
        activation: Activation function to use
        
    Example:
        >>> module = MyModule(features=128)
        >>> y = module(x)
    """
    features: int
    activation: Callable[[Array], Array] = nn.relu
    
    def __init__(self, features: int, *, rngs: nn.Rngs):
        self.features = features
        self.linear = nn.Linear(features, rngs=rngs)
        
    def __call__(self, x: Float[Array, "batch in_features"]) -> Float[Array, "batch features"]:
        """Forward pass of the module."""
        return self.activation(self.linear(x))
```

## Environment Variables
```bash
# Add to ~/.zshrc or appropriate shell config
export GEMINI_PROJECT_ROOT="${HOME}/projects"
export GEMINI_PYTHON_VERSION="3.11"
export UV_PYTHON_PREFERENCE="only-managed"
```

## Quick Reference

### When Starting New Project
1. `uvnew project-name 3.11`
2. `cd project-name && uvsetup`
3. Create proper project structure (including docs/)
4. Add jaxtyping and dev dependencies
5. Set up pre-commit hooks

### Before Committing
1. Run type checking: `uv run mypy src/ --strict`
2. Run linting: `uv run ruff check src/`
3. Run tests: `uv run pytest tests/`
4. Format code: `uv run ruff format src/`

### Branch Management
- Always branch from `dev-main` for new features
- Use `dev-<feature>` for development
- Use `test-<feature>` for experiments
- Only merge to `main` from `dev-main` after full testing

### Git Commit Requirements
**CRITICAL**: Git commits must NEVER:
- Mention AI, Gemini, Google AI, or any AI tool
- Include phrases like "AI-generated", "Gemini helped", etc.
- Reference that code was written by an AI
- Include AI-related emojis or signatures

**ALWAYS**: Write commits that:
- Describe ONLY what changed in the code
- Focus on the technical changes made
- Use conventional commit format when applicable
- Sound like they were written by a human developer

**Example Good Commits**:
- `fix: resolve type errors in data loader`
- `feat: add JAX-based model training loop`
- `refactor: simplify array operations using jax.vmap`
- `docs: update API documentation for NNX modules`

**Example Bad Commits** (NEVER USE):
- ❌ `AI: fixed type errors`
- ❌ `Gemini helped implement training loop`
- ❌ `feat: add model (generated by Gemini)`
- ❌ `🤖 update documentation`

## Custom Shell Functions

These functions are available in the shell environment:

### Git Branch Management
```bash
# Create a new development branch from dev-main
dev <feature-name>     # Creates dev-<feature-name> branch
# Example: dev new-model → creates dev-new-model

# Create a new test/experimental branch from dev-main  
test <feature-name>    # Creates test-<feature-name> branch
# Example: test api-endpoint → creates test-api-endpoint

# Check branch status relative to dev-main
branch-status          # Shows commits ahead and files changed
```

### Quality Checks
```bash
# Run all configured quality checks (ruff, mypy, tests)
qc                     # Automatically detects and runs available tools
```

### Existing UV Functions
```bash
uvnew <project> <version>  # Create new UV project
uvsetup                    # Sync dependencies and activate venv
uvupgrade                  # Upgrade all dependencies
```

## Additional Notes
- Prefer functional approaches with JAX transformations
- Use NNX for all neural network implementations
- Always profile before optimizing JAX code
- Document computational complexity in docstrings
- Include shape annotations for all array operations
- Ensure docs/ directory exists in every project for documentation