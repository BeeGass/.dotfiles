---
description: Always use the LSP tool as the primary means of navigating and understanding code
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.c"
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.hpp"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.java"
  - "**/*.kt"
  - "**/*.lua"
  - "**/*.zig"
  - "**/*.cu"
  - "**/*.cuh"
---

# LSP Usage

ALWAYS use the LSP tool as the primary means of navigating, exploring, and understanding code. The LSP provides semantic understanding — resolving types, following imports, and understanding language structure — that grep and glob cannot. Treat the LSP as the default; only fall back to grep/glob when the LSP cannot answer the question.

## Required: Use LSP first for these operations

- **Navigating to code** — use goToDefinition/goToImplementation instead of grepping for function or class names. This is faster and always correct.
- **Understanding impact before changes** — use findReferences before renaming, refactoring, moving, or deleting any symbol. Never guess at callers.
- **Reading type info** — use hover to inspect type signatures, inferred types, generics, and docstrings instead of reading entire files.
- **Exploring file structure** — use documentSymbol to see all functions, classes, and variables in a file before reading it.
- **Finding symbols across the project** — use workspaceSymbol to locate classes, functions, and constants by name.
- **Tracing call chains** — use prepareCallHierarchy, incomingCalls, and outgoingCalls to understand how code flows through the codebase.

## Workflow integration

- **Before reading a file**: run documentSymbol to understand its structure, then jump to specific symbols with goToDefinition rather than reading top-to-bottom.
- **Before editing**: use findReferences to understand the full blast radius of the change. Use hover to confirm types.
- **After editing**: use hover and findReferences to verify the edit didn't break type contracts or miss call sites.
- **When exploring unfamiliar code**: chain goToDefinition calls to follow the code path. This is dramatically faster than grepping.

## Fallback to grep/glob only when

- The LSP server is unavailable or not configured for the language
- Searching for string literals, comments, or log messages (not symbols)
- Doing broad regex pattern matching across file contents
- The LSP server has not finished indexing (retry after a brief pause)
