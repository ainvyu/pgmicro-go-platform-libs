package pgmicro_libs

import (
	"path"
	"testing"

	"github.com/ebitengine/purego"
	"github.com/stretchr/testify/require"
)

// Smoke test — walks the embed tree and, if a real library artifact
// is bundled, dlopens it and calls `turso_version`.
//
// Note: the C ABI symbol name is still `turso_version` even with the
// `default-postgres` feature ON, because pgmicro's sdk-kit did not
// rename its public symbols when it forked from Turso. The Go-level
// library filename changes (libpgmicro_sdk_kit.*), the symbol names
// inside the library do not.
//
// In the skeleton state (empty placeholder library files), Load()
// returns a clean error and this test skips — CI that runs before
// the build step can import the module without failing.
var (
	turso_version func() string
)

func TestLoad(t *testing.T) {
	t.Log(libraryFilename())
	t.Log(embeddedLibraryPath())

	var list func(p string)
	list = func(p string) {
		file, err := libs.Open(p)
		t.Log("open", p, err)
		if err != nil {
			return
		}

		stat, err := file.Stat()
		t.Log("stat", stat, err)
		if err != nil {
			return
		}

		if !stat.IsDir() {
			return
		}

		dirs, err := libs.ReadDir(p)
		t.Log("read_dir", dirs, err)
		if err != nil {
			return
		}

		for _, dir := range dirs {
			list(path.Join(p, dir.Name()))
		}
	}
	list(".")

	library, err := LoadPgmicroLibrary(LoadPgmicroLibraryConfig{LoadStrategy: MixedLibraryLoadStrategy})
	if err != nil {
		t.Skipf("no real pgmicro library bundled yet (skeleton state ok): %v", err)
	}

	purego.RegisterLibFunc(&turso_version, library, "turso_version")
	t.Log("turso_version", turso_version())
	require.NotEmpty(t, turso_version())
}
