# Claude-specific functions for development workflows

# Git branch management following dev-main pattern
dev() {
    local feature_name=$1
    if [[ -z "$feature_name" ]]; then
        echo "Usage: dev <feature-name>"
        echo "Examples: dev new-model, dev document, dev train-loop"
        return 1
    fi
    
    # Always branch from dev-main
    git checkout dev-main && git pull && git checkout -b "dev-${feature_name}"
}

test() {
    local feature_name=$1
    if [[ -z "$feature_name" ]]; then
        echo "Usage: test <feature-name>"
        echo "Examples: test new-model, test api-endpoint"
        return 1
    fi
    
    # Test branches for experiments
    git checkout dev-main && git pull && git checkout -b "test-${feature_name}"
}

# Quick quality check - uses whatever linting/type checking is configured
qc() {
    # Run ruff if available
    if command -v ruff &> /dev/null || uv run ruff --version &> /dev/null 2>&1; then
        echo "Running ruff..."
        uv run ruff check . && uv run ruff format --check .
    fi
    
    # Run mypy if configured
    if [[ -f "pyproject.toml" ]] && grep -q "mypy" "pyproject.toml"; then
        echo "Running mypy..."
        uv run mypy .
    fi
    
    # Run tests if they exist
    if [[ -d "tests" ]]; then
        echo "Running tests..."
        uv run pytest tests/ -v
    fi
}

# Show current branch status relative to dev-main
branch-status() {
    local current_branch=$(git branch --show-current)
    echo "Current branch: $current_branch"
    
    if [[ "$current_branch" != "dev-main" ]] && [[ "$current_branch" != "main" ]]; then
        echo "\nCommits ahead of dev-main:"
        git log dev-main..HEAD --oneline
        
        echo "\nFiles changed:"
        git diff dev-main --name-status
    fi
}