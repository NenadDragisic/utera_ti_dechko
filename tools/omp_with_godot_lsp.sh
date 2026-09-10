#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly GODOT_LAUNCHER="$SCRIPT_DIR/start_godot_lsp.sh"
readonly GODOT_PORT="6015"
readonly GODOT_START_TIMEOUT_SECONDS="15"
readonly WINDOWS_GODOT_CHECK='$ErrorActionPreference = "Stop"; try { $processes = @(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -like "Godot*" }); if ($processes.Count -gt 0) { exit 10 }; exit 0 } catch { Write-Error $_; exit 11 }'

godot_pid=""

is_active_child() {
	local expected_pid="$1"
	local active_pid
	while read -r active_pid; do
		[[ "$active_pid" == "$expected_pid" ]] && return 0
	done < <(jobs -pr)
	return 1
}

listener_is_owned_by() {
	local expected_pid="$1"
	local listeners
	listeners="$(/usr/bin/ss -H -ltnp "sport = :$GODOT_PORT" 2>/dev/null)" || return 1
	[[ "$listeners" == *"pid=$expected_pid,"* ]]
}

cleanup() {
	local status=$?
	trap - EXIT INT TERM
	if [[ -n "$godot_pid" ]]; then
		if is_active_child "$godot_pid"; then
			kill "$godot_pid" 2>/dev/null || true
		fi
		wait "$godot_pid" 2>/dev/null || true
		printf 'Stopped Linux Godot LSP.\n'
	fi
	exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if ! command -v powershell.exe >/dev/null 2>&1; then
	printf 'Cannot verify whether Windows Godot is running: powershell.exe is unavailable.\n' >&2
	exit 1
fi
if ! command -v omp >/dev/null 2>&1; then
	printf 'OMP is unavailable on PATH.\n' >&2
	exit 1
fi
if [[ ! -x "$GODOT_LAUNCHER" ]]; then
	printf 'Godot LSP launcher is missing or not executable: %s\n' "$GODOT_LAUNCHER" >&2
	exit 1
fi
if [[ ! -x /usr/bin/nc ]]; then
	printf 'Godot LSP readiness probe is unavailable: /usr/bin/nc\n' >&2
	exit 1
fi
if [[ ! -x /usr/bin/ss ]]; then
	printf 'Godot LSP socket ownership check is unavailable: /usr/bin/ss\n' >&2
	exit 1
fi

set +e
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$WINDOWS_GODOT_CHECK"
windows_check_status=$?
set -e
case "$windows_check_status" in
	0)
		;;
	10)
		printf 'Windows Godot is running. Close it before starting the Linux Godot LSP.\n' >&2
		exit 1
		;;
	*)
		printf 'Could not determine whether Windows Godot is running (PowerShell exit %s).\n' "$windows_check_status" >&2
		exit 1
		;;
esac

if /usr/bin/nc -z -w 1 127.0.0.1 "$GODOT_PORT" 2>/dev/null; then
	printf 'Port %s is already in use. Stop the existing process before continuing.\n' "$GODOT_PORT" >&2
	exit 1
fi

printf 'Starting Linux Godot LSP on 127.0.0.1:%s...\n' "$GODOT_PORT"
"$GODOT_LAUNCHER" &
godot_pid=$!

ready=0
read -r uptime _ < /proc/uptime
deadline=$(( ${uptime%%.*} + GODOT_START_TIMEOUT_SECONDS ))
while true; do
	if ! is_active_child "$godot_pid"; then
		set +e
		wait "$godot_pid"
		godot_status=$?
		set -e
		godot_pid=""
		printf 'Linux Godot exited before its LSP became ready (exit %s).\n' "$godot_status" >&2
		exit 1
	fi

	read -r uptime _ < /proc/uptime
	now=${uptime%%.*}
	if (( now >= deadline )); then
		break
	fi
	remaining=$(( deadline - now ))
	if /usr/bin/nc -z -w "$remaining" 127.0.0.1 "$GODOT_PORT" 2>/dev/null; then
		if ! listener_is_owned_by "$godot_pid"; then
			printf 'Port %s was claimed by a process other than the launched Linux Godot.\n' "$GODOT_PORT" >&2
			exit 1
		fi
		if ! is_active_child "$godot_pid"; then
			continue
		fi
		ready=1
		break
	fi
	sleep 0.1
done

if [[ "$ready" -ne 1 ]]; then
	printf 'Linux Godot LSP did not become ready on port %s within %s seconds.\n' \
		"$GODOT_PORT" "$GODOT_START_TIMEOUT_SECONDS" >&2
	exit 1
fi

printf 'Godot LSP ready; starting OMP.\n'
cd -- "$PROJECT_DIR"
set +e
omp "$@"
omp_status=$?
set -e
exit "$omp_status"
