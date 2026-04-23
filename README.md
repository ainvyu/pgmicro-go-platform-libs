# pgmicro-go-platform-libs

Pre-compiled platform-specific libraries for the pgmicro Go driver.

## Attribution

This repository is a fork of
[tursodatabase/turso-go-platform-libs](https://github.com/tursodatabase/turso-go-platform-libs)
(MIT License, © 2025 Turso Database). The upstream layout, build-script
structure, and Go loader scaffolding are preserved; see `LICENSE` for the
upstream copyright notice, which continues to apply to this fork.

Modifications © 2026 ainvyu, released under the same MIT License.

## Summary of changes vs. upstream

- Go package renamed `turso_libs` → `pgmicro_libs`; module path
  `github.com/tursodatabase/turso-go-platform-libs` →
  `github.com/ainvyu/pgmicro-go-platform-libs`.
- Public API: `LoadTursoLibrary[Config]` → `LoadPgmicroLibrary[Config]`;
  `LibraryName` constant `libturso_sync_sdk_kit` → `libpgmicro_sdk_kit`.
- Env var `TURSO_GO_CACHE_DIR` → `PGMICRO_GO_CACHE_DIR`; user cache dir
  `turso-go/<hash>` → `pgmicro-go/<hash>`.
- Build scripts: `TURSO_RS_*` → `PGMICRO_*`; default source repo now points
  at the pgmicro fork used by this driver.
- Build scripts: `--features default-postgres` added to the cargo invocation
  so the produced dylib parses PostgreSQL syntax. The upstream cargo crate
  name (`turso_sdk_kit`) is kept and the produced binary is renamed to
  `libpgmicro_sdk_kit.*` when copied into `libs/<platform>/`.
- GitHub Actions workflow: musl builds cross-compiled via `zig cc` from a
  glibc host (replacing the prior Alpine/bindgen path) to dodge libclang
  discovery failures on Alpine. Workflow input `turso_ref` → `pgmicro_ref`,
  branch prefix `turso-branch-` → `pgmicro-branch-`.

See the initial bootstrap commit for the full diff.

## License

MIT — see [`LICENSE`](./LICENSE). The upstream copyright line is retained
verbatim and the fork's modifications are covered by an additional
copyright line in the same file.
