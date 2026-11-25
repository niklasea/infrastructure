# C# / .NET

## Lane map

| Lane | Focus | When |
|---|---|---|
| `csharp-correctness` | Async, disposal, nullability, exceptions, DI, EF, concurrency | Any `.cs` change |
| `csharp-api` | Public surface, compatibility, naming, nullability contracts | Any public type or member change, `ref/` assembly change |
| `csharp-tests` | Test quality, regression coverage, AI-written assertions | Any test change or behavior change |
| `csharp-security` | Input, authz, injection, deserialization, secrets | Auth, data access, file/network input |
| `csharp-performance` | Allocations, GC, LINQ, EF queries, hot paths | Performance-sensitive or high-volume code |

## CI already covers

The build, analyzers, nullable warnings, formatting, and test runner are deterministic. Do not flag:

- compiler errors, analyzer warnings, StyleCop or `.editorconfig` violations;
- formatting, using order, or naming that the analyzers enforce;
- missing `using` directives or obvious syntax issues;
- test failures that CI already reports.

If the toolchain is unavailable, say so and mark runtime claims as `needs_validation`.

## Shared evidence

Prefer a caller trace or a failing test. Cite `path:line` and the contract being violated. For async issues, trace the call path and the synchronization context. For API breaks, cite the public signature and the consumer.

## Correctness

- **Async.** `async` all the way; no `.Result`, `.Wait()`, or `GetAwaiter().GetResult()` on async code. `CancellationToken` plumbed through. `ConfigureAwait(false)` in libraries, not required in ASP.NET Core request paths. No `async void` except event handlers. `Task.Run` only for CPU-bound work.
- **Disposal.** `IDisposable`/`IAsyncDisposable` implemented correctly; `using` for all disposables; no leaked streams, handlers, or timers.
- **Nullability.** Nullable reference types enabled; `!` justified; public contracts annotated; no null-forgiving to silence a real flow.
- **Exceptions.** Catch specific exceptions; no empty catch; no exceptions for control flow; preserve stack traces with `throw;`; no swallowing in background tasks.
- **DI.** Lifetimes correct (singleton must not capture scoped); options validated; no service locator; no captive dependencies.
- **Concurrency.** Shared state protected; `ConcurrentDictionary`/locks used correctly; no double-checked locking without `volatile`/`Lazy`; `Interlocked` where needed.
- **EF Core.** Tracking vs `AsNoTracking`; N+1 queries; client evaluation; transaction scope; concurrency tokens; raw SQL parameterized.
- **LINQ.** Multiple enumeration; deferred execution captured in a closure; `Count()` vs `Any()`; materialization where needed.
- **Time and culture.** `DateTimeOffset` vs `DateTime`; UTC boundaries; `CultureInfo.InvariantCulture` for parsing/formatting; time zones.
- **Resources and limits.** Timeouts on HTTP calls; bounded channels/queues; no unbounded caches.

## API

- **Public surface.** New public types/members, changed signatures, removed overloads, changed default parameter values.
- **Compatibility.** Binary and source compatibility; `ref/` assembly changes; `InternalsVisibleTo` additions; interface members that break implementers.
- **Contracts.** Nullability annotations, default values, exceptions documented, cancellation tokens, `ValueTask` versus `Task`.
- **Design.** Naming, records versus classes, equality, immutability, `sealed`, `readonly`.
- **Blocking rule.** Any new public API surface requires explicit API approval or a human decision. Treat it as `important` at minimum; `blocker` if it breaks compatibility.

## Tests

- **Behavior, not implementation.** Tests assert observable behavior; no brittle reflection or private-member coupling.
- **Regression tests.** A bug fix includes a test that fails before the fix.
- **AI-written tests.** Verify the assertion matches the intended behavior. An AI can encode a bug as the expected result.
- **Determinism.** No `Thread.Sleep`, real clocks, network, or order dependence; use `TimeProvider` or fakes.
- **Coverage gaps.** Error paths, cancellation, empty/null inputs, concurrency, boundary values.

## Security

- Input validation at trust boundaries; parameterized SQL; no command/path injection; safe deserialization; no secrets in code or logs; authorization on every resource access; CSRF for cookie-auth endpoints; correct crypto (no custom crypto, no ECB, no static IV).

## Performance

- Allocations and boxing in hot paths; `Span<T>`/`Memory<T>` where justified; `ValueTask` only with a real benefit; `StringBuilder` for loops; avoid `params` arrays in hot paths.
- EF: project only needed columns, avoid N+1, use compiled queries where measured.
- Logging: structured, no string interpolation in disabled log levels; no expensive `ToString()` in hot paths.

## False-positive traps

- `ConfigureAwait(false)` is not required in ASP.NET Core application code.
- `Task.Run` in a UI event handler can be correct.
- A `!` may be justified after an explicit guard.
- `async void` is acceptable for event handlers.
- `IDisposable` on a class that owns nothing is noise.
- Analyzer/style findings are CI's job, not the reviewer's.
- Do not assert that an API "does not exist" or "is deprecated" from model knowledge; check the repository.

## Gate commands

```bash
dotnet build --nologo
dotnet test --nologo
dotnet format --verify-no-changes
git diff --check
```
