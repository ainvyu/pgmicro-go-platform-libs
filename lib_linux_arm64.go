//go:build linux && arm64 && !musl

package pgmicro_libs

import "embed"

//go:embed libs/linux_arm64/*
var libs embed.FS
