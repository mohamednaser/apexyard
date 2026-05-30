# LSP Usage — Prefer Language Servers Over Text Search

When an LSP plugin is installed for the project's language (e.g. `typescript-lsp`, `php-lsp`), **use the LSP for code-aware operations**. Text-grep is a fallback, not the default. Currently installed in this fork: `typescript-lsp@claude-plugins-official` (project scope).

## When to use the LSP

| Task | Use the LSP, not… |
|------|-------------------|
| "Where is `X` defined?" | …`grep` for the function name |
| "What calls `X`?" | …`grep` for call sites |
| "What's the type of this expression?" | …reading several files to reconstruct the type |
| "Rename `X` across the codebase" | …`sed` / `Edit` with `replace_all` |
| "Are there errors in this file?" | …running the full `tsc` build to find one mistake |
| "What does this import resolve to?" | …reading `tsconfig.json` paths by hand |
| "What are the available methods on this value?" | …guessing from related code |

LSP operations are **semantic** — they understand scope, types, modules, and aliases. Grep is **lexical** — it matches strings and misses renamed re-exports, dynamic dispatch, type-only references, and shadowed names.

## When grep / text search is still right

- Searching for **non-code text**: log messages, comments, copy strings, config keys, URLs.
- Languages with **no LSP installed** in this fork.
- **First-pass discovery** when you do not yet know a symbol's name (e.g. "find anything related to billing"). Once you have a symbol, switch to the LSP.
- **Build / lint / test output** — diagnostics from the toolchain are authoritative for the toolchain.

## Workflow

1. Before grepping for a symbol, ask: *would the LSP answer this faster?* If yes, call the LSP tool.
2. Before a wide `Edit … replace_all` on an identifier, prefer the LSP rename — it skips strings/comments/unrelated tokens that share the name.
3. Before declaring a refactor "done", check LSP diagnostics on the changed files. Don't rely on text search alone to catch broken references.
4. If the LSP plugin appears unhealthy (errors, no response, stale results), say so and fall back to text search rather than silently ignoring it.

## Why

Grep on a typed codebase is a foot-gun. It finds the literal string, not the symbol — so renames miss aliased imports, "find references" misses type positions, and "is this used?" misses dynamic call sites the type system already knows about. The LSP is the same engine the human's editor uses; using it keeps Claude's mental model of the code aligned with the developer's.
