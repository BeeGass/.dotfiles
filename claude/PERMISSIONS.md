# Claude Code Permissions

## Allowed Commands

### File Operations
- Read any file in the project directory

### Git Operations
- `git status`, `git diff`, `git log`
- `git add`, `git commit`
- `git checkout`, `git branch`
- `git merge` (only from dev-* to dev-main)
- `git pull`, `git fetch`

### Python/UV Operations
- All `uv` commands
- `python` execution for testing/debugging
- Package installation via `uv add`

### Quality Checks
- `ruff check`, `ruff format`
- `mypy`, `pyright`
- `pytest` and test execution
- `pre-commit` hooks

### Development Tools
- `grep`, `find`, `ls`, `cd`
- `tree` for directory visualization
- `repo_to_text` for repository exports
- Environment variable inspection
- Process monitoring for development

## Restricted Commands

### System Operations
- NO system configuration changes
- NO service management (systemctl, etc.)
- NO user/permission modifications
- NO network configuration

### Git Operations  
- NO `git push` without explicit request
- NO `git merge` to `main` (only to `dev-main`)
- NO force operations (`-f`, `--force`)
- NO repository deletion

### Package Management
- NO global package installations
- NO system Python modifications
- NO pip usage (use UV exclusively)

## Best Practices

1. **Always ask before**:
   - Making commits
   - Creating new repositories
   - Installing new dependencies
   - Running resource-intensive operations

2. **Never perform**:
   - Destructive operations without confirmation
   - Changes outside the project directory
   - Modifications to dotfiles without request

3. **Default behavior**:
   - Read and analyze freely
   - Suggest changes rather than implement
   - Explain consequences of operations
   - Use dry-run options when available