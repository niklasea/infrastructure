# Rust

## Lane map

| Lane | Focus | When |
|---|---|---|
| `rust-soundness` | `unsafe`, aliasing, FFI, `Send`/`Sync`, panics | Any `unsafe`, FFI, or concurrency change |
| `rust-api` | Public API, semver, error types, ownership, async | Any public item or signature change |
| `rust-tests` | Unit/integration/property/fuzz coverage, regression tests | Any behavior change |
| `rust-performance` | Allocations, clones, locking, benchmarks | Hot paths or perf claims |

## CI already covers

`cargo check`, `clippy`, `rustfmt`, and `cargo test` are deterministic. Do not flag:

- compiler errors, borrow-checker errors, clippy warnings, formatting;
- missing `unsafe` blocks around already-unsafe operations;
- style lints that `clippy` enforces;
- test failures CI already reports.

If the toolchain is unavailable, say so and mark runtime claims as `needs_validation`.

## Shared evidence

Soundness claims need a concrete path to undefined behavior, not just the presence of `unsafe`. API claims need the public signature and a consumer or semver argument. Performance claims need a benchmark or a clear allocation path.

## Soundness

- **Unsafe blocks.** Every `unsafe` block has a valid safety argument. `# Safety` docs on public unsafe functions. No `unsafe` used to silence the borrow checker without justification.
- **Aliasing and provenance.** No simultaneous `&mut` and `&`; pointer arithmetic stays in bounds; `MaybeUninit` initialized before read; `transmute` layouts checked; lifetimes not extended past the referent.
- **Send/Sync.** Manual `unsafe impl Send/Sync` has a proof; interior mutability is synchronized; `Rc`/`RefCell` not shared across threads.
- **FFI.** `repr(C)` layouts, null handling, ownership transfer documented, panics do not cross the boundary, destructors run exactly once.
- **Panics.** Panics in library code that callers cannot handle; `unwrap`/`expect` on untrusted input; panics across FFI.
- **Arithmetic.** Overflow behavior in release; unchecked indexing; `as` casts that truncate.
- **Drop and leaks.** `mem::forget`, `ManuallyDrop`, double-free, use-after-free.
- **Tools.** Miri for tests that reach `unsafe`; fuzzing for parsers and FFI; sanitizers where Miri cannot run.

## API

- **Semver.** Breaking changes to public items, trait bounds, enum variants, struct fields, function signatures.
- **Bounds.** Over-constrained generics; missing `?Sized`; sealed traits; `#[non_exhaustive]` for extensible enums/structs.
- **Errors.** `thiserror` for libraries, `anyhow` at application boundaries; `From` conversions; no stringly typed errors in public APIs.
- **Ownership in signatures.** `&str` vs `String`, `&[T]` vs `Vec<T>`, `impl Trait`, `Cow`, `AsRef`; avoid needless clones.
- **Async.** Cancellation safety; `Send` futures; runtime assumptions (`tokio` vs `async-std`); blocking calls inside async.
- **Features.** Additive feature flags; no feature that silently changes behavior; default features documented.
- **Docs.** Public items documented; examples compile; `# Panics`, `# Errors`, `# Safety` sections.

## Tests

- **Behavior.** Tests assert observable behavior, not implementation details.
- **Regression.** A bug fix includes a test that fails before the fix.
- **Unsafe invariants.** Tests that exercise the safety argument; Miri where possible.
- **Property and fuzz.** Parsers, codecs, and state machines get property tests or fuzzing.
- **Edge cases.** Empty input, boundaries, overflow, cancellation, error paths.
- **Benchmarks.** Performance claims need a benchmark, not an assertion.

## Performance

- **Allocations.** Needless `clone`, `to_string`, `Vec` growth, `format!` in hot paths.
- **Iterators.** Lazy chains that recompute; `collect` into an intermediate; bounds checks that can be hoisted.
- **Locking.** Contention, lock held across await, `Mutex` vs `RwLock`, sharding.
- **Async overhead.** Spawning per item; unbounded concurrency; blocking in async.
- **Evidence.** A benchmark or a profile; otherwise mark `needs_validation`.

## False-positive traps

- `unsafe` is not inherently wrong; demand a concrete UB path.
- `unwrap` in tests, examples, or after an explicit invariant check can be fine.
- Clippy pedantic warnings are not review findings.
- A clone may be the simplest correct choice; require a measured hot path.
- Do not claim a type is not `Send`/`Sync` without checking the impls and fields.
- Do not assert crate/API behavior from model knowledge; check `Cargo.toml` and the source.

## Gate commands

```bash
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo deny check
cargo miri test          # optional, only when configured
git diff --check
```
