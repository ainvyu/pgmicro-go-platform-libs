//go:build darwin && arm64

package pgmicro_libs

import "embed"

//go:embed libs/darwin_arm64/*
var libs embed.FS
