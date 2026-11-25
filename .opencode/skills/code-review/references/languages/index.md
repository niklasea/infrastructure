# Language references

Match changed paths to a reference, then pick at most three lanes. Rank by blast radius.

| Paths | Reference | Default lanes |
|---|---|---|
| `terraform/**/*.tf`, `**/*.tfvars`, `**/*.tftpl`, `**/.terraform.lock.hcl` | `terraform.md` | `terraform-correctness`, `terraform-security`, `terraform-operability` |
| `ansible/**/*.yml`, `ansible/**/*.yaml`, `ansible/**` | `ansible.md` | `ansible-correctness`, `ansible-security`, `ansible-operability` |
| `.github/workflows/**` | `github-actions.md` | `actions-supply-chain` |
| `**/Dockerfile`, `**/Dockerfile.*`, `dockerfiles/**` | `dockerfile.md` | `container-hardening` |
| `**/*.cs`, `**/*.csproj`, `**/*.sln`, `**/*.props`, `**/*.targets` | `csharp.md` | `csharp-correctness`, `csharp-api`, `csharp-tests`; add `csharp-security` for auth/data changes |
| `**/*.rs`, `Cargo.toml`, `Cargo.lock` | `rust.md` | `rust-soundness`, `rust-api`, `rust-tests`; add `rust-performance` for hot paths |
| Anything else | `generic.md` | `generic-correctness`, `generic-security` |

## Rules

- Read only the **Lane map** and **CI already covers** sections before dispatch. The lane agent reads the rest.
- If several references match, run one lane per reference, up to three total. Merge the lowest-risk lanes into one if needed.
- Skip generated files, lockfiles, vendored code, and pure formatting changes. Say so in the report.
- A docs-only diff gets a `generic` consistency check, not a full review.
- Do not apply a language reference to a file it does not cover.
- If a reference is missing, use `generic.md` and say the review was language-agnostic.
