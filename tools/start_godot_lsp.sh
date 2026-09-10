#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly GODOT_BINARY="${GODOT_LSP_BINARY:-$HOME/.local/bin/godot-4.7.2}"
readonly GODOT_PORT="6015"
readonly GODOT_LOG="${GODOT_LSP_LOG:-/tmp/utera-ti-dechko-godot-lsp.log}"

if [[ ! -x "$GODOT_BINARY" ]]; then
	printf 'Godot LSP binary is missing or not executable: %s\n' "$GODOT_BINARY" >&2
	printf 'Install Godot 4.7.2 for Linux or set GODOT_LSP_BINARY.\n' >&2
	exit 1
fi

exec "$GODOT_BINARY" \
	--headless \
	--editor \
	--path "$PROJECT_DIR" \
	--lsp-port "$GODOT_PORT" \
	--log-file "$GODOT_LOG"
