# ast-grep Cheatsheet

Prefer ast-grep over grep for structural code searches (finding function calls, class definitions, imports, specific syntax patterns).

## Basic Usage

```bash
# Search for a pattern
ast-grep -p 'PATTERN' [path]

# Search with language specified
ast-grep -p 'PATTERN' -l js src/

# Interactive rewrite
ast-grep -p 'OLD_PATTERN' --rewrite 'NEW_PATTERN' --interactive -l ts src/
```

## Pattern Syntax

- Metavariables use `$UPPERCASE` to match any AST node
- Always use single quotes to prevent shell expansion
- Patterns match structure, not text (whitespace-insensitive)

## Key Parameters

- `-p, --pattern`: Search pattern
- `-l, --lang`: Language (js, ts, tsx, py, rs, go, java, etc.)
- `--rewrite`: Replacement pattern
- `--interactive`: Approve changes interactively
- `-A`: Show lines after match
- `-B`: Show lines before match

## JavaScript/TypeScript Examples

```bash
# Find function calls
ast-grep -p '$FUNC($$$ARGS)' -l js

# Find property access patterns
ast-grep -p '$OBJ.$PROP()' -l ts

# Find console statements
ast-grep -p 'console.log($$$)' -l js

# Find specific imports
ast-grep -p 'import $X from "react"' -l tsx

# Find conditional property calls
ast-grep -p '$PROP && $PROP()' -l ts

# Find arrow functions
ast-grep -p 'const $VAR = ($$$) => $$$' -l ts

# Find async functions
ast-grep -p 'async function $FUNC($$$) { $$$ }' -l js
```

## Python Examples

```bash
# Find function definitions
ast-grep -p 'def $FUNC($$$): $$$' -l py

# Find class definitions
ast-grep -p 'class $CLASS: $$$' -l py

# Find method calls
ast-grep -p '$OBJ.$METHOD($$$)' -l py

# Find imports
ast-grep -p 'from $MODULE import $$$' -l py

# Find list comprehensions
ast-grep -p '[$EXPR for $VAR in $ITER]' -l py

# Find decorators
ast-grep -p '@$DECORATOR' -l py

# Find try-except blocks
ast-grep -p 'try: $$$ except $EXC: $$$' -l py
```

## Rust Examples

```bash
# Find function definitions
ast-grep -p 'fn $FUNC($$$) -> $RET { $$$ }' -l rs

# Find struct definitions
ast-grep -p 'struct $NAME { $$$ }' -l rs

# Find impl blocks
ast-grep -p 'impl $TRAIT for $TYPE { $$$ }' -l rs

# Find macro invocations
ast-grep -p '$MACRO!($$$)' -l rs

# Find match expressions
ast-grep -p 'match $EXPR { $$$ }' -l rs

# Find unwrap calls (code smell)
ast-grep -p '$EXPR.unwrap()' -l rs

# Find clone calls
ast-grep -p '$EXPR.clone()' -l rs
```
