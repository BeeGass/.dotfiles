# Git Workflow & Commits

## Commit Message Format (Conventional Commits)

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only changes
- `style`: Formatting, missing semicolons, etc. (no code change)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates
- `ci`: CI/CD changes
- `build`: Build system or external dependencies

**Examples:**

```
feat(auth): add OAuth2 authentication

Implements OAuth2 flow with Google and GitHub providers.
Includes token refresh logic and session management.

Closes #123
```

```
fix(parser): handle empty input correctly

Previously crashed on empty string input. Now returns empty result.
```

```
refactor(ml): simplify model architecture definition

Use nnx.Sequential instead of manual layer composition for cleaner code.
```

**Rules:**

- Use lowercase for type and subject
- Subject line <= 50 characters
- Body wraps at 72 characters
- Use imperative mood ("add" not "added")
- Reference issues/PRs in footer
- Breaking changes: Add `BREAKING CHANGE:` in footer

## Branch Naming

- `feat/short-description`: New features
- `fix/short-description`: Bug fixes
- `refactor/short-description`: Refactoring
- `docs/short-description`: Documentation
- Use kebab-case for descriptions

## Git Best Practices

- **Atomic commits**: Each commit should be a single logical change
- **Commit often**: Small, frequent commits are better than large ones
- **Review before commit**: Use `git diff --staged` to review changes
- **No WIP commits**: Clean up commits before pushing to shared branches
- **Meaningful history**: Rebase/squash when appropriate for cleaner history
