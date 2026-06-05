#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-debug}"

case "$MODE" in
	debug)
		odin build . -debug
		;;
	release)
		odin build . -disable-assert -o:speed
		;;
	*)
		echo "Usage: $0 [debug|release]" >&2
		exit 1
		;;
esac
