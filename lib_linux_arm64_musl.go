//go:build linux && arm64 && musl

package pgmicro_libs

import "embed"

//go:embed libs/linux_arm64_musl/*
var libs embed.FS

func init() {
	isMusl = true
}
