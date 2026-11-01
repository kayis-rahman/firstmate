#!/usr/bin/env bash
set -eu
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export FM_ROOT=${FM_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}
exec "$SCRIPT_DIR/go-pilot/image-gen" "$@"
