# Project-Specific CLAUDE.md Template

<!-- This template shows how to create a project-specific CLAUDE.md that inherits from the system-wide configuration -->

# [Project Name] Configuration

<!-- Import the system-wide configuration -->
<!-- @import ~/.dotfiles/claude/CLAUDE.md -->

## Overrides

```overrides
# Project-specific permission overrides
- ALLOW: Create API documentation in docs/api/
- ALLOW: Generate migration files in migrations/
- MODIFY: Include vendor/ in search scope for debugging
```

## Project Information

### Overview

Brief description of the project, its purpose, and key technologies.

### Tech Stack

- **Language**: [e.g., Python 3.11, TypeScript]
- **Framework**: [e.g., FastAPI, Next.js]
- **Database**: [e.g., PostgreSQL, MongoDB]
- **Testing**: [e.g., pytest, jest]

### Project Structure

```
project/
├── src/           # Source code
├── tests/         # Test files
├── docs/          # Documentation
└── ...            # Other project-specific directories
```

## Project-Specific Commands

### Development

```bash
# Start development server
npm run dev

# Run with hot reload
python -m uvicorn app.main:app --reload
```

### Quality Checks

```bash
# Project-specific lint command
npm run lint

# Type checking
npm run typecheck

# Run all checks
npm run check:all
```

### Testing

```bash
# Unit tests
npm test

# Integration tests
npm run test:integration

# E2E tests
npm run test:e2e
```

## Project Conventions

### Code Style

- Additional style rules specific to this project
- Framework-specific patterns to follow
- Naming conventions unique to this codebase

### Git Workflow

- Project-specific branch naming if different
- PR requirements
- Deployment branches

## API Endpoints (if applicable)

```
GET  /api/users     - List users
POST /api/users     - Create user
GET  /api/users/:id - Get user details
...
```

## Environment Variables

```bash
# Required environment variables
DATABASE_URL=
API_KEY=
SECRET_KEY=
```

## Common Tasks

### Adding a New Feature

1. Create feature branch from dev-main
2. Implement with TDD approach
3. Update documentation
4. Create PR with tests

### Debugging Production Issues

1. Check logs in logs/
2. Review recent deployments
3. Use debugging tools: [list tools]

## Known Issues / Gotchas

- List any project-specific quirks
- Common errors and solutions
- Performance considerations

## External Dependencies

- Third-party services used
- API integrations
- External documentation links

## Notes

- Any additional project-specific information
- Architectural decisions
- Future considerations

<!--
Remember: This file inherits ALL settings from the system-wide CLAUDE.md
Only add project-specific information and overrides here
-->
