# Tool Usage Configuration

## Tool Prioritization

### Search Strategy Hierarchy
1. **Task Agent**: For complex, multi-step searches
2. **Grep/Glob**: For targeted, specific searches
3. **Read**: For known file locations
4. **LS**: For directory exploration

### Parallel Execution Mandate
**CRITICAL**: Always maximize parallel operations:
- Launch multiple Task agents concurrently
- Batch related tool calls in single messages
- Use 7-parallel-Task method for complex features
- Combine independent operations

## Task Agent Guidelines

### When to Use Task Agent
- **ALWAYS** for open-ended searches requiring multiple rounds
- **ALWAYS** when searching for keywords across codebase
- **ALWAYS** for "which file does X?" questions
- **ALWAYS** for complex analysis requiring multiple tools

### When NOT to Use Task Agent
- Specific file path reads (use Read)
- Class definition searches (use Glob)
- Code within 2-3 known files (use Read)
- Writing code (use Edit/Write)
- Running commands (use Bash)

### Task Agent Best Practices
```markdown
Prompt Structure:
1. Clear, specific objective
2. Expected information to return
3. Search boundaries/constraints
4. Output format requirements
```

## File Operations

### Read Tool Usage
- **MUST** read before any edit operation
- **BATCH** multiple file reads in parallel
- **CACHE** awareness - files are cached 15 minutes
- **IMAGES** supported for screenshots/diagrams

### Edit Tool Hierarchy
1. **MultiEdit**: Preferred for multiple changes
2. **Edit**: Single change with unique context
3. **Write**: Only for new files (avoid when possible)

### Edit Tool Requirements
- **UNIQUE CONTEXT**: Old string must be unique
- **EXACT MATCH**: Include all whitespace/indentation
- **PRESERVE STYLE**: Match existing code patterns
- **ATOMIC EDITS**: All succeed or none apply

## Search Tools

### Grep Configuration
```yaml
Defaults:
  output_mode: "files_with_matches"
  multiline: false (true for cross-line patterns)
  case_sensitive: true (use -i for insensitive)

Prefer:
  - Specific file types (type: "py")
  - Glob patterns for known structures
  - Head limits for large results
```

### Glob Patterns
```bash
Common Patterns:
- "**/*.py" - All Python files
- "**/test_*.py" - All test files
- "src/**/*.ts" - TypeScript in src
- "*.{js,jsx,ts,tsx}" - Multiple extensions
```

## Bash Execution

### Command Safety Rules
- **QUOTE PATHS**: Always quote paths with spaces
- **AVOID**: find, grep, cat, head, tail, ls commands
- **USE**: Grep, Glob, Read, LS tools instead
- **EXPLAIN**: What command does before running

### Command Patterns
```bash
# Good - Absolute paths
pytest /home/user/project/tests

# Bad - Using cd
cd /home/user/project && pytest tests

# Good - Proper quoting
python "/path with spaces/script.py"

# Bad - Unquoted paths
python /path with spaces/script.py
```

## Web Operations

### WebFetch Usage
- **CHECK**: For MCP-provided alternatives first
- **CACHE**: 15-minute self-cleaning cache
- **REDIRECTS**: Follow redirect URLs provided
- **PROMPTS**: Specific extraction instructions

### WebSearch Guidelines
- **DOMAINS**: Use allowed/blocked domain filters
- **DATES**: Account for current date in queries
- **SCOPE**: US-only availability
- **PURPOSE**: Current events and recent data

## Quality Assurance

### Testing Tools
- **pytest**: With coverage flags
- **mypy/pyright**: Strict type checking
- **ruff**: Linting and formatting
- **pre-commit**: Automated checks

### Verification Workflow
```bash
# Always run after implementation
uv run mypy src/ --strict
uv run ruff check src/
uv run pytest tests/ -v
```

## Tool Combination Patterns

### Feature Implementation
```yaml
1. Parallel Tasks:
   - Search existing implementations
   - Read documentation
   - Check test patterns
   
2. Sequential Steps:
   - Read → Edit → Test → Verify
   
3. Batch Operations:
   - Multiple file edits with MultiEdit
   - Parallel quality checks
```

### Debugging Workflow
```yaml
1. Parallel Analysis:
   - Read error logs
   - Search similar issues
   - Check documentation
   
2. Targeted Fixes:
   - MultiEdit for related changes
   - Test specific functions
```

## Performance Optimization

### Token Efficiency
- **BATCH** related operations
- **PARALLEL** independent tasks
- **CACHE** awareness for repeated access
- **TARGETED** searches over broad scans

### Context Management
- **MINIMIZE** unnecessary reads
- **FOCUS** on relevant code sections
- **PRUNE** large outputs with limits
- **REUSE** Task agent results