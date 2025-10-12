# Claude Command: Commit

## Core Function
Creates conventional commits with automated analysis and quality checks.

## Usage
```
/commit [options]
```

### Options
- `--no-verify`: Skip pre-commit validation
- `--interactive`: Review each change group manually
- `--dry-run`: Preview commits without execution
- `--force-single`: Commit all changes as single unit
- `--message "text"`: Override generated message
- `--scope "text"`: Force specific scope

## Execution Flow

### 1. Pre-commit Validation (unless --no-verify)
```bash
uv run ruff check .
uv run ruff format --check .
uv run mypy .
```

### 2. Change Detection
- Check staged files via `git status`
- Auto-stage all modified/new files if none staged
- Generate comprehensive diff analysis

### 3. Commit Strategy Analysis
**Single commit when:**
- Changes affect single concern/feature
- Total diff under 200 lines
- All changes share same commit type

**Multiple commits when:**
- Mixed commit types (feat + fix + docs)
- Unrelated file groups modified
- Logical separation improves clarity
- Individual changes exceed atomic principle

### 4. Message Generation
**Format:** `<type>(<scope>): <description>`

**Types:** feat, fix, docs, style, refactor, perf, test, chore

**Rules:**
- Imperative mood, present tense
- First line ≤72 characters
- Body wrapped at 72 characters
- Reference issues in footer
- No emojis or AI references

## Commit Splitting Logic

### Automatic Split Triggers
1. **File type separation:** source code vs docs vs config
2. **Functional boundaries:** API changes vs UI changes vs tests
3. **Size thresholds:** Individual logical units >100 lines
4. **Dependency chains:** Prerequisites before dependent features

### Split Examples
```
Original: Large authentication system
Split into:
├── feat(auth): add JWT token validation
├── feat(auth): implement password hashing
├── docs(auth): update API documentation
├── test(auth): add authentication test suite
└── chore: update security dependencies
```

## Message Templates

### Single-line Format
```
feat(api): add user authentication endpoint
fix(parser): resolve memory leak in data processing
docs(readme): update installation requirements
refactor(utils): simplify error handling logic
```

### Multi-line Format
```
feat(payment): implement Stripe integration

- Add payment processing with webhook validation
- Implement subscription management endpoints
- Create transaction logging with audit trail
- Add automated invoice generation

Closes #145, #167
Breaking-change: Legacy payment API deprecated
```

## Error Recovery

**Pre-commit failure:** Abort or force-proceed options
**Merge conflicts:** Halt execution, require manual resolution
**Invalid staging:** Auto-correct or manual intervention
**Message validation:** Regenerate with corrections

## Quality Gates

- Validate conventional commit format
- Ensure description clarity and specificity
- Verify scope accuracy
- Confirm breaking change documentation
- Check issue reference format
