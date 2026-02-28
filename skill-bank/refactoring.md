# Skill Template: Refactoring

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific patterns and conventions.

## When to Use

Use this skill when the task restructures existing code without changing its external behaviour.

## Safety Protocol

1. Run all tests before starting — confirm baseline is green
2. Make one logical change at a time
3. Run all tests after each change
4. Run all tests at the end

## Common Refactoring Patterns

### Extract Function/Method
Extract when a block has a clear single purpose, exceeds ~10 lines, is duplicated, or lives inside deep nesting. Identify inputs/outputs, create a named function, replace the block with a call.

### Rename
Must update every reference — imports, tests, docs, config, string references, log messages. Search the entire codebase, not just IDE rename.

### Move Code Between Modules
Copy to destination, update imports in all referencing files, check for circular imports, delete from original. Watch for re-exports.

### Simplify Conditionals
Use early returns/guard clauses instead of deep nesting. Use lookup tables instead of if/elif chains.

### Remove Dead Code
Grep for all references (including dynamic/string-based), check exports and entry points. If unused, delete. Do not comment out.

## Backward Compatibility

When refactoring public APIs: keep old interface working, add deprecation signal, set removal timeline, migrate callers before removing.

## Anti-Patterns

- Big-bang refactoring (change everything at once)
- Refactoring without tests (write tests first)
- Mixing refactoring with behaviour changes
- Premature abstraction (wait for two concrete use cases)
