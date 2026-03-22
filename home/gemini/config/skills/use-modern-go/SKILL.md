---
name: use-modern-go
description: Enforces modern Go best practices based on the project's Go version (e.g., Go 1.23+ iterators, 1.24+ t.Context). Use when writing or refactoring Go code to ensure it uses the latest idiomatic patterns and avoids "legacy" or "manual" implementations.
---

# Modern Go Guidelines

This skill ensures Go code adheres to modern best practices, prioritizing built-in features and standard library enhancements over legacy manual patterns.

## 1. Version Detection

Before making changes or providing recommendations, detect the project's Go version:

```bash
# Check go.mod for the version
grep '^go [0-9.]*' go.mod | awk '{print $2}'
```

### Communication Protocol

- **If version is detected:** State: *"This project is using Go X.XX, so I’ll stick to modern Go best practices and freely use language features up to and including this version."*
- **If version is unknown:** State: *"Could not detect Go version in this repository. Which version should I target? (e.g., 1.23, 1.24, 1.25, 1.26)"*

## 2. Core Directives

1. **Strict Versioning:** Use **all** features available up to the target version. Never use features from a future version.
2. **Standard Library First:** Prefer `slices`, `maps`, and `cmp` packages over manual implementations or third-party libraries for basic operations.
3. **No Legacy Patterns:** Replace manual loops with built-ins (e.g., `min`, `max`, `clear`) when the target version supports them.

## 3. Modern Patterns

Refer to [references/modern-go-patterns.md](references/modern-go-patterns.md) for a complete list of modern patterns by version, including:

- **Go 1.21-1.23:** `min`/`max`, `clear`, `slices`/`maps` packages, iterators.
- **Go 1.24+:** `t.Context()`, `omitzero` tag, `b.Loop()`, `strings.SplitSeq`.
- **Go 1.25+:** `wg.Go(fn)` for `sync.WaitGroup`.
- **Go 1.26+:** `new(30)` for value pointers, `errors.AsType[T](err)`.

## 4. Refactoring Strategy

When refactoring, look for:
- Manual `for` loops filtering/mapping slices (replace with `slices.DeleteFunc`, etc.).
- `interface{}` usage (replace with `any`).
- Manual `time.Since` or `time.Until` (ensure they are used correctly).
- Manual error joining (use `errors.Join`).
