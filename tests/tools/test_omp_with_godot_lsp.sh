#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
readonly WRAPPER="$PROJECT_DIR/tools/omp_with_godot_lsp.sh"
readonly TEMP_DIR="$(mktemp -d)"
readonly FAKE_BIN="$TEMP_DIR/bin"
readonly GODOT_PID_FILE="$TEMP_DIR/godot.pid"
readonly RIVAL_PID_FILE="$TEMP_DIR/rival.pid"
readonly OMP_CWD_FILE="$TEMP_DIR/omp.cwd"
readonly OMP_ARGS_FILE="$TEMP_DIR/omp.args"

stop_pid_file() {
	local pid_file="$1"
	if [[ -f "$pid_file" ]]; then
		local pid
		pid="$(cat "$pid_file")"
		if kill -0 "$pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null || true
			wait "$pid" 2>/dev/null || true
		fi
	fi
}

cleanup() {
	stop_pid_file "$GODOT_PID_FILE"
	stop_pid_file "$RIVAL_PID_FILE"
	rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

assert_contains() {
	local haystack="$1"
	local needle="$2"
	[[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_stopped() {
	local pid
	pid="$(cat "$GODOT_PID_FILE")"
	if kill -0 "$pid" 2>/dev/null; then
		fail "Godot process $pid is still running"
	fi
	if /usr/bin/nc -z -w 1 127.0.0.1 6015 2>/dev/null; then
		fail 'port 6015 is still accepting connections'
	fi
}

mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/powershell.exe" <<'FAKE_POWERSHELL'
#!/usr/bin/env bash
exit "${FAKE_WINDOWS_CHECK_STATUS:-0}"
FAKE_POWERSHELL

cat > "$FAKE_BIN/omp" <<'FAKE_OMP'
#!/usr/bin/env bash
printf '%s\n' "$PWD" > "$FAKE_OMP_CWD_FILE"
printf '%s\n' "$@" > "$FAKE_OMP_ARGS_FILE"
exit "${FAKE_OMP_EXIT_STATUS:-0}"
FAKE_OMP

cat > "$FAKE_BIN/listener.py" <<'FAKE_LISTENER'
import signal
import socket

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", 6015))
server.listen()

def stop(_signum, _frame):
    raise SystemExit(0)

signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)
while True:
    connection, _address = server.accept()
    connection.close()
FAKE_LISTENER

cat > "$FAKE_BIN/godot" <<'FAKE_GODOT'
#!/usr/bin/env bash
printf '%s\n' "$$" > "$FAKE_GODOT_PID_FILE"
listener="$(dirname -- "$0")/listener.py"
if [[ "${FAKE_GODOT_MODE:-normal}" == 'rival' ]]; then
	python3 "$listener" </dev/null >/dev/null 2>&1 &
	printf '%s\n' "$!" > "$FAKE_RIVAL_PID_FILE"
	for ((attempt = 0; attempt < 100; attempt++)); do
		/usr/bin/nc -z -w 1 127.0.0.1 6015 2>/dev/null && break
		sleep 0.01
	done
	sleep 0.5
	exit 1
fi
exec python3 "$listener"
FAKE_GODOT

chmod 0755 "$FAKE_BIN/powershell.exe" "$FAKE_BIN/omp" "$FAKE_BIN/godot"

if [[ ! -x "$WRAPPER" ]]; then
	fail "expected executable wrapper at $WRAPPER"
fi

common_env=(
	"PATH=$FAKE_BIN:$PATH"
	"GODOT_LSP_BINARY=$FAKE_BIN/godot"
	"FAKE_GODOT_PID_FILE=$GODOT_PID_FILE"
	"FAKE_OMP_CWD_FILE=$OMP_CWD_FILE"
	"FAKE_OMP_ARGS_FILE=$OMP_ARGS_FILE"
	"FAKE_RIVAL_PID_FILE=$RIVAL_PID_FILE"
)

set +e
windows_output="$(env "${common_env[@]}" FAKE_WINDOWS_CHECK_STATUS=10 "$WRAPPER" 2>&1)"
windows_status=$?
set -e
[[ "$windows_status" -ne 0 ]] || fail 'wrapper started while Windows Godot was reported running'
assert_contains "$windows_output" 'Windows Godot is running'
[[ ! -e "$GODOT_PID_FILE" ]] || fail 'Linux Godot started during Windows-process refusal'
[[ ! -e "$OMP_CWD_FILE" ]] || fail 'OMP started during Windows-process refusal'

rm -f "$GODOT_PID_FILE" "$OMP_CWD_FILE" "$OMP_ARGS_FILE"
set +e
env "${common_env[@]}" FAKE_GODOT_MODE=rival "$WRAPPER" >/dev/null 2>&1
race_status=$?
set -e
stop_pid_file "$RIVAL_PID_FILE"
rm -f "$RIVAL_PID_FILE"
[[ "$race_status" -ne 0 ]] || fail 'wrapper accepted a port owned by a different process'
[[ ! -e "$OMP_CWD_FILE" ]] || fail 'OMP started against a port owned by a different process'

happy_output="$(env "${common_env[@]}" "$WRAPPER" alpha 'two words' 2>&1)" || fail "happy path failed: $happy_output"
[[ "$(cat "$OMP_CWD_FILE")" == "$PROJECT_DIR" ]] || fail 'OMP did not start from the project root'
mapfile -t forwarded_args < "$OMP_ARGS_FILE"
[[ "${#forwarded_args[@]}" -eq 2 ]] || fail 'OMP did not receive exactly two arguments'
[[ "${forwarded_args[0]}" == 'alpha' && "${forwarded_args[1]}" == 'two words' ]] || fail 'OMP arguments were not forwarded verbatim'
assert_stopped

rm -f "$GODOT_PID_FILE" "$OMP_CWD_FILE" "$OMP_ARGS_FILE"
set +e
env "${common_env[@]}" FAKE_OMP_EXIT_STATUS=23 "$WRAPPER" >/dev/null 2>&1
omp_status=$?
set -e
[[ "$omp_status" -eq 23 ]] || fail "expected OMP exit 23, got $omp_status"
assert_stopped

printf 'PASS: supervised OMP/Godot lifecycle\n'
