# pgmicro-go-platform-libs

Pre-compiled platform-specific libraries for the pgmicro Go driver.

Forked from [`tursodatabase/turso-go-platform-libs`](https://github.com/tursodatabase/turso-go-platform-libs) and rebuilt against [`glommer/pgmicro`](https://github.com/glommer/pgmicro) with the `default-postgres` cargo feature enabled, so the embedded `libpgmicro_sdk_kit.{so,dylib,dll}` speaks Postgres syntax rather than SQLite.

## Usage

```go
import (
    pgmicro "github.com/ainvyu/pgmicro-go-platform-libs"
    "github.com/ebitengine/purego"
)

handle, err := pgmicro.LoadPgmicroLibrary(pgmicro.LoadPgmicroLibraryConfig{
    LoadStrategy: pgmicro.MixedLibraryLoadStrategy,
})
if err != nil { /* ... */ }

var tursoVersion func() string
purego.RegisterLibFunc(&tursoVersion, handle, "turso_version")
fmt.Println(tursoVersion())
```

### Load strategies

| Strategy | Behavior |
|---|---|
| `EmbeddedLibraryLoadStrategy` (default) | `go:embed`된 dylib을 OS 캐시(`$PGMICRO_GO_CACHE_DIR` or `os.UserCacheDir()/pgmicro-go/<hash>/`)로 추출 후 dlopen. |
| `SystemLibraryLoadStrategy` | `$PATH`/`$LD_LIBRARY_PATH`/`$DYLD_LIBRARY_PATH` + 현재 디렉터리에서 `libpgmicro_sdk_kit` 검색. |
| `MixedLibraryLoadStrategy` | embedded 시도 → 실패 시 system fallback. |

### Env overrides

- `PGMICRO_GO_CACHE_DIR` — embedded 모드의 라이브러리 추출 기본 경로를 덮어쓴다.

## Repository layout

```
.
├── build_libs.sh / build_libs.cmd    # pgmicro 소스 체크아웃 + cargo build (default-postgres)
├── hash_libs.sh / hash_libs.cmd      # SHA-256 sidecar 생성
├── libs/<platform>/                  # CI가 빌드 결과를 넣는 위치
│   ├── libpgmicro_sdk_kit.{so,dylib,dll,a}
│   └── libpgmicro_sdk_kit.*.sha256
├── load_pgmicro.go                   # 메인 로더
├── load_library_purego.go            # linux/darwin dlopen (via purego)
├── load_library_windows.go           # windows LoadLibrary
├── lib_<os>_<arch>.go                # platform-split go:embed directives
└── .github/workflows/build.yml       # 5-target × default-postgres CI
```

## Building locally

```bash
# Clone pgmicro at a pinned ref, build turso_sdk_kit with default-postgres,
# and rename the output to libpgmicro_sdk_kit.* under libs/<platform>/:
PGMICRO_BUILD_REF=master ./build_libs.sh
./hash_libs.sh
```

Required: Rust stable, git. Optional: `rustup` for musl cross-targets.

## Releasing

1. Trigger `.github/workflows/build.yml` manually with `pgmicro_ref` set to the upstream git ref.
2. CI fans out across 5 native runners (ubuntu amd64, ubuntu arm64, macos amd64/arm64, windows amd64) plus 2 Alpine/musl variants.
3. Per-platform artifacts are aggregated into a `pgmicro-branch-<ref>` branch. Tag push follows SemVer convention.
4. `go get github.com/ainvyu/pgmicro-go-platform-libs@<tag>` consumes the bundled dylibs via `go:embed`.

## Relationship to upstream

This repo deliberately mirrors the file layout of `turso-go-platform-libs` so the Go bindings at `github.com/glommer/pgmicro/bindings/go` can be forked with a two-line import swap:

```diff
- import turso_libs "github.com/tursodatabase/turso-go-platform-libs"
+ import pgmicro_libs "github.com/ainvyu/pgmicro-go-platform-libs"
- handle, err := turso_libs.LoadTursoLibrary(...)
+ handle, err := pgmicro_libs.LoadPgmicroLibrary(...)
```

The C-ABI symbol names inside the library (`turso_database_new`, `turso_statement_step`, etc.) are unchanged — pgmicro's sdk-kit inherits the Turso symbol set because it IS the Turso sdk-kit, just compiled with a different dialect feature.

## Prerequisite (upstream patch)

pgmicro's `sdk-kit/Cargo.toml` does not yet declare the `default-postgres` feature. Building from a vanilla pgmicro checkout requires applying this one-line addition first (or pointing `PGMICRO_REPO` at a fork that has it):

```diff
 # sdk-kit/Cargo.toml
 [features]
 encryption = ["turso_core/encryption"]
 pure-rust-crypto = ["turso_core/pure-rust-crypto"]
+default-postgres = ["turso_core/default-postgres"]
```

Additionally, mirror the JS SDK's runtime option block (`bindings/javascript/src/lib.rs:287`) into `sdk-kit/src/rsapi.rs`'s database-open path so `with_postgres`, `with_views`, `with_custom_types`, `with_attach`, and `with_generated_columns` are turned on under the feature gate.

See `docs/SPEC-pgmicro-go-sdk.md` in the consuming TAP repo for the broader context.

## License

MIT. Inherits from upstream pgmicro and Turso.
