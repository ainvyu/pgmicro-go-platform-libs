//go:build linux && amd64 && !musl

package pgmicro_libs

import "embed"

//go:embed libs/linux_amd64/*
var libs embed.FS
