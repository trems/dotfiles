# Modern Go Patterns

This reference provides a comprehensive list of modern Go patterns and features, categorized by the version they were introduced in.

## General Modernization (Go 1.0 - 1.20)

- **`interface{}` -> `any`**: Use `any` for all new code.
- **Time**: Use `time.Since(start)` and `time.Until(deadline)` instead of `time.Now().Sub(start)`.
- **Errors**: Use `errors.Is(err, target)` for comparisons and `errors.Join(err1, err2)` for multiple errors.
- **Strings/Bytes**:
  - Use `strings.Cut` for splitting.
  - Use `strings.Clone` to avoid memory sharing.
  - Use `strings.CutPrefix`/`strings.CutSuffix` instead of manual slicing.
- **Atomics**: Use type-safe atomics like `atomic.Bool` or `atomic.Pointer[T]`.

## Standard Library Enhancements (Go 1.21 - 1.23)

- **Built-ins**: Use `min(a, b)`, `max(a, b)`, and `clear(map_or_slice)`.
- **Slices/Maps Packages**:
  - `slices.Contains`, `slices.Sort`, `slices.Clone`, `slices.DeleteFunc`.
  - `maps.Keys(m)`, `maps.Copy`, `maps.DeleteFunc`.
- **Loops**: Use `for i := range n` (Go 1.22+).
- **Iterators (Go 1.23+)**:
  - Use `slices.Collect(iter)` and `slices.Sorted(iter)`.
  - Use `iter.Seq` and `iter.Seq2` for custom iterators.
- **Tickers**: Use `time.Tick` freely; the GC now handles cleanup.

## Advanced Modern Patterns (Go 1.24 - 1.26)

### Testing (Go 1.24+)
Use `t.Context()` instead of manually creating a context:
```go
// Modern (1.24+)
ctx := t.Context()

// Legacy
ctx, cancel := context.WithCancel(context.Background())
t.Cleanup(cancel)
```

### JSON (Go 1.24+)
Use `omitzero` instead of `omitempty` for `time.Duration`, `time.Time`, structs, and slices:
```go
type MyStruct struct {
    LastUpdated time.Time `json:"last_updated,omitzero"`
}
```

### Benchmarks (Go 1.24+)
Use `for b.Loop()` instead of manual loops:
```go
// Modern (1.24+)
for b.Loop() {
    // benchmark logic
}

// Legacy
for i := 0; i < b.N; i++ {
    // benchmark logic
}
```

### Sequences (Go 1.24+)
Use `strings.SplitSeq` when iterating over split results to avoid allocating the intermediate slice.

### Concurrency (Go 1.25+)
Use `wg.Go(fn)` for `sync.WaitGroup` for cleaner goroutine management:
```go
// Modern (1.25+)
wg.Go(func() { ... })

// Legacy
wg.Add(1)
go func() {
    defer wg.Done()
    ...
}()
```

### Pointers & Error Casting (Go 1.26+)
- **Direct Pointers**: Use `new(30)` instead of `x := 30; &x`.
- **Error Casting**: Use `errors.AsType[T](err)` instead of the pointer-passing `errors.As(err, &target)`.
