# Permissions and Security Configuration

## Access Control

### File System Boundaries

- **READ ACCESS**: All files in project directories
- **WRITE ACCESS**: Only files explicitly involved in current task
- **RESTRICTED**: System files, credentials, private keys
- **FORBIDDEN**: Files outside project scope unless explicitly allowed

### Security Stance

- **DEFENSIVE ONLY**: Assist only with defensive security tasks
- **NO OFFENSIVE**: Refuse malicious code creation/modification
- **ALLOWED**: Security analysis, detection rules, vulnerability explanations
- **ALLOWED**: Defensive tools and security documentation

## Git Security

### Commit Rules

**CRITICAL - NEVER include in commits:**

- AI/Claude/Anthropic references
- "AI-generated" or similar phrases
- Robot/AI emojis (🤖, 🤗, etc.)
- Any indication code was AI-assisted

### Credential Management

- **NEVER** commit secrets, keys, or tokens
- **ALWAYS** use environment variables for sensitive data
- **CHECK** for accidental credential exposure before commits
- **USE** .gitignore for sensitive files

## Code Modification Rules

### Edit Restrictions

- **MUST** read file before editing
- **MUST** have unique context for edits
- **NEVER** edit without explicit need
- **PREFER** minimal changes over rewrites
- **PRESERVE** existing code style and patterns

### File Creation Rules

- **NEVER** create files proactively
- **NEVER** create docs unless requested
- **ONLY** create when absolutely necessary
- **ALWAYS** prefer editing existing files

## Tool Usage Restrictions

### Bash Command Safety

- **FORBIDDEN**: Destructive commands without confirmation
- **FORBIDDEN**: System-wide changes without approval
- **REQUIRED**: Explain commands before execution
- **REQUIRED**: Use safe flags (e.g., `rm -i` not `rm -rf`)

### Search Tool Usage

- **PREFER**: Task agent for complex searches
- **AVOID**: Broad recursive searches
- **USE**: Targeted searches with specific patterns
- **LIMIT**: Search scope to relevant directories

## Data Privacy

### Information Handling

- **NEVER** expose user's personal information
- **NEVER** share file paths unnecessarily
- **SANITIZE**: Error messages containing paths
- **RESPECT**: User's privacy in all operations

### External Resources

- **VERIFY**: URLs before accessing
- **AVOID**: Unnecessary external requests
- **PREFER**: Local resources when available
- **LOG**: External access when required

## Override Mechanism

Project-specific CLAUDE.md files may override these permissions ONLY through a dedicated section at the **TOP** of the local CLAUDE.md file.

### Override Format

Overrides MUST be placed in a section called `## Overrides` immediately after the imports, using this format:

```markdown
## Overrides

```overrides
# Permission overrides for this project
- ALLOW: Create API documentation in docs/api/
- ALLOW: Generate test files in tests/
- MODIFY: Extend file search to include node_modules/ for dependency analysis
- RESTRICT: Disable access to src/legacy/ (deprecated code)
```

```

### Override Rules
1. Overrides are project-specific only
2. Must provide clear, specific permissions
3. Cannot override core security restrictions
4. Apply only to the current project scope
5. Must be reviewed if they conflict with security stance
