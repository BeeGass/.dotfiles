# Workflow Configuration

## Planning Requirements

### Mandatory Planning Phase

**CRITICAL**: Before ANY implementation:

1. **Analyze Request**: Fully understand requirements
2. **Create Clear Plan**: Break into actionable steps
3. **Use TodoWrite**: Document all planned steps
4. **Review Dependencies**: Check affected files/systems
5. **Identify Risks**: Note potential breaking changes

### Planning Template

```markdown
## Task: [Brief Description]

### Current State Analysis
- [ ] Read relevant files
- [ ] Understand existing patterns
- [ ] Identify dependencies

### Implementation Plan
1. [Specific action with file/location]
2. [Next action with dependencies]
3. [Testing/verification step]

### Risk Assessment
- Breaking changes: [List any]
- Dependencies: [External/internal]
- Testing needs: [Specific tests]
```

## Todo Management

### TodoWrite Usage Rules

**ALWAYS use TodoWrite when:**

- Task has 3+ distinct steps
- Working on complex features
- User provides multiple tasks
- Discovering new subtasks
- Tracking parallel work

**SKIP TodoWrite when:**

- Single, trivial tasks
- Pure conversation/info
- Tasks under 3 simple steps

### Todo State Management

```yaml
States:
  pending: Not started yet
  in_progress: Currently working (MAX 1)
  completed: Finished successfully

Rules:
  - Only ONE in_progress at a time
  - Update states in real-time
  - Complete immediately when done
  - Never mark incomplete work as done
```

### Todo Patterns

```markdown
Good Todo Items:
✓ "Implement user authentication with JWT"
✓ "Fix type errors in data/loader.py"
✓ "Add unit tests for auth module"

Bad Todo Items:
✗ "Fix stuff"
✗ "Make changes"
✗ "Update code"
```

## Execution Workflows

### Feature Implementation Flow

```mermaid
1. Research Phase (Parallel)
   ├── Search existing patterns
   ├── Read relevant files
   └── Check documentation

2. Planning Phase
   ├── Create detailed todos
   ├── Identify dependencies
   └── Plan test strategy

3. Implementation Phase
   ├── Make changes (MultiEdit)
   ├── Run quality checks
   └── Execute tests

4. Verification Phase
   ├── Lint and type check
   ├── Run test suite
   └── Verify requirements met
```

### Debugging Workflow

```yaml
1. Reproduce & Analyze:
   - Read error messages
   - Identify failure points
   - Search for similar issues

2. Investigate Root Cause:
   - Examine relevant code
   - Check recent changes
   - Review dependencies

3. Fix & Verify:
   - Apply targeted fixes
   - Test specific scenarios
   - Ensure no regressions
```

### Code Review Workflow

```yaml
1. Understand Context:
   - Read PR description
   - Review changed files
   - Check test coverage

2. Analyze Changes:
   - Verify code quality
   - Check for issues
   - Suggest improvements

3. Provide Feedback:
   - Clear, actionable comments
   - Security considerations
   - Performance implications
```

## Quality Assurance

### Pre-Commit Verification

**ALWAYS ensure before marking task complete:**

- **Type Safety**: Code passes type checking
- **Code Quality**: Linting checks pass
- **Formatting**: Code follows project style
- **Testing**: All tests pass successfully
- **Documentation**: Updated where needed
- **Security**: No exposed secrets or vulnerabilities

### Definition of Done

Task is ONLY complete when:

- ✓ All code changes implemented
- ✓ Tests pass successfully
- ✓ Type checking passes
- ✓ Linting passes
- ✓ No security issues
- ✓ Requirements verified

### Quality Check Commands

```bash
# Run project-specific quality checks
# Check README or ask user for specific commands
# Common patterns include:
- Type checking (mypy, pyright, tsc)
- Linting (ruff, eslint, flake8)
- Testing (pytest, jest, vitest)
- Formatting (black, prettier, ruff format)
- Security scanning (bandit, safety)
```

## Parallel Execution

### Parallel Task Patterns

```python
# Good - Parallel execution
tasks = [
    Task("Search for auth implementations"),
    Task("Read configuration files"),
    Task("Check test patterns"),
    Task("Review documentation")
]
# Launch all simultaneously

# Bad - Sequential execution
task1.complete()
then task2.start()
then task3.start()
```

### Parallel Guidelines

- **DEFAULT**: Assume parallel execution
- **BATCH**: Group related operations
- **MAXIMIZE**: Concurrent tool usage
- **COORDINATE**: Results from parallel tasks

## Error Handling

### Error Response Pattern

```yaml
1. Capture Error:
   - Full error message
   - Stack trace if available
   - Context of failure

2. Analyze:
   - Root cause
   - Similar issues
   - Potential fixes

3. Resolve:
   - Apply minimal fix
   - Test specific case
   - Verify broader impact
```

### Blocked State Handling

When blocked:

1. Keep task as `in_progress`
2. Create new todo for blocker
3. Document what's needed
4. Ask user for guidance

## Communication

### Progress Updates

- Brief status when starting major tasks
- Explain complex operations
- Report completion of milestones
- Ask for clarification when needed

### Response Patterns

```markdown
# Starting task
"Implementing authentication system using JWT tokens."

# During execution
"Found 3 type errors in auth module, fixing now."

# Completion
"Authentication implemented and tested successfully."

# Blocked
"Need database credentials to proceed with testing."
```

## Git Workflow Integration

### Branch Operations

```bash
# Feature development
dev feature-name    # Create dev branch
# ... implement feature ...
# ... run quality checks ...
# Create PR from dev-feature-name

# Experimental work
test feature-name   # Create test branch
# ... experiment freely ...
# Merge to dev if successful
```

### Commit Patterns

- Make logical, atomic commits
- Write clear commit messages
- Never reference AI assistance
- Follow conventional commits

## Optimization Strategies

### Token Efficiency

1. Read only necessary files
2. Use targeted searches
3. Batch related operations
4. Leverage caching

### Time Efficiency

1. Parallel by default
2. Minimize round trips
3. Predictive actions
4. Efficient tool selection

### Context Management

1. Focus on current task
2. Prune irrelevant info
3. Summarize long outputs
4. Maintain task state
