# OMP Godot LSP Tooling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a project-local, token-efficient OMP integration with Godot 4.7.2's GDScript language server while preserving the existing Windows test and export toolchain.

**Architecture:** A foreground Linux Godot 4.7.2 editor process runs inside WSL and exposes GDScript LSP on loopback TCP port 6015. OMP spawns `/usr/bin/nc` as its stdio language-server command, while concise project instructions make narrow semantic navigation the default and the existing PowerShell/GUT gate remains authoritative for behavior.

**Tech Stack:** Godot 4.7.2-stable standard Linux and Windows builds, typed GDScript, OMP project LSP configuration, OpenBSD netcat, Bash, PowerShell, GUT 9.7.0.

**Spec:** `docs/superpowers/specs/2026-09-09-omp-godot-lsp-design.md`

## Global Constraints

- Use the official Godot 4.7.2-stable standard Linux build with version `4.7.2.stable.official.ed1daf0bf` for LSP.
- Verify the Linux archive SHA-256 as `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4` before extraction.
- Keep every downloaded binary outside the repository; `~/.local/bin/godot-4.7.2` is the default executable path.
- Keep the existing Windows Godot executable and `tools/test.ps1` authoritative for automated verification and exports.
- Use loopback port 6015 for the Linux LSP service; do not connect OMP to the Windows editor's default port 6005.
- Stop the Linux Godot editor before Windows import, full tests, or exports touch the same `.godot` directory.
- Register only `.gd` files. Do not claim semantic coverage for `.tscn`, `.tres`, or `.gdshader`.
- Use `/usr/bin/nc`; do not add Node, Rust, npm, Cargo, or another package manifest for the transport.
- Preserve OMP defaults for lazy startup, shared servers, diagnostic deduplication, and formatting; do not add `.omp/config.yml` without a demonstrated need.
- Do not modify, stage, or overwrite the user's existing change in `features/settings/settings_view.tscn`.
- Do not modify gameplay or test behavior as part of this tooling change.

## File map

```text
.omp/
├── AGENTS.md               # Concise LSP-first project instructions
└── lsp.json                # OMP GDScript server registration
tools/
└── start_godot_lsp.sh      # Foreground native-Linux Godot LSP launcher
docs/
└── setup/
    └── godot-development.md # Installation, lifecycle, recovery, and verification guide
```

---

### Task 1: Native Godot launcher and OMP server registration

**Files:**
- Create: `tools/start_godot_lsp.sh`
- Create: `.omp/lsp.json`

**Interfaces:**
- Consumes: official executable at `${GODOT_LSP_BINARY:-$HOME/.local/bin/godot-4.7.2}`, `/usr/bin/nc`, repository-root `project.godot`, and loopback TCP port 6015.
- Produces: foreground command `tools/start_godot_lsp.sh` and OMP server key `godot-gdscript` for `.gd` files.

- [ ] **Step 1: Establish the failing integration baseline**

From the repository root, invoke the OMP LSP `status` action before creating `.omp/lsp.json`.

Expected: `No language servers configured for this project`.

Confirm that the Linux binary is not assumed to exist:

```bash
test ! -e "$HOME/.local/bin/godot-4.7.2" || "$HOME/.local/bin/godot-4.7.2" --version
```

Expected: either the path is absent, or the existing command reports exactly the pinned 4.7.2 stable build. Do not replace an unrelated existing file.

- [ ] **Step 2: Create the foreground launcher**

Create `tools/start_godot_lsp.sh` with exactly one process-management responsibility:

```bash
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
```

Make only this script executable:

```bash
chmod 0755 tools/start_godot_lsp.sh
```

- [ ] **Step 3: Prove launcher syntax and failure behavior**

Run:

```bash
bash -n tools/start_godot_lsp.sh
GODOT_LSP_BINARY=/definitely/missing/godot tools/start_godot_lsp.sh
```

Expected:

- `bash -n` exits 0.
- The second command exits nonzero.
- Stderr names `/definitely/missing/godot` and says to install Godot 4.7.2 or set `GODOT_LSP_BINARY`.
- No Godot process remains running.

- [ ] **Step 4: Register the custom OMP server**

Create `.omp/lsp.json`:

```json
{
  "servers": {
    "godot-gdscript": {
      "command": "/usr/bin/nc",
      "args": ["127.0.0.1", "6015"],
      "fileTypes": [".gd"],
      "languageId": "gdscript",
      "rootMarkers": ["project.godot"],
      "warmupTimeoutMs": 15000
    }
  }
}
```

Reload the OMP workspace LSP configuration and invoke `status`.

Expected: `godot-gdscript` is configured but not started while the Linux editor is absent. No unrelated built-in server is disabled by this custom entry.

- [ ] **Step 5: Install and verify the matching Linux editor outside the repository**

If `~/.local/bin/godot-4.7.2` is not already the correct build, run:

```bash
mkdir -p "$HOME/.local/opt/godot-4.7.2" "$HOME/.local/bin"
curl -L --fail \
  -o /tmp/Godot_v4.7.2-stable_linux.x86_64.zip \
  https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
printf '%s  %s\n' \
  'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4' \
  '/tmp/Godot_v4.7.2-stable_linux.x86_64.zip' \
  | sha256sum -c -
unzip -o /tmp/Godot_v4.7.2-stable_linux.x86_64.zip \
  -d "$HOME/.local/opt/godot-4.7.2"
chmod 0755 "$HOME/.local/opt/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"
ln -sfn \
  "$HOME/.local/opt/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64" \
  "$HOME/.local/bin/godot-4.7.2"
rm -f /tmp/Godot_v4.7.2-stable_linux.x86_64.zip
```

Verify:

```bash
"$HOME/.local/bin/godot-4.7.2" --version
```

Expected: `4.7.2.stable.official.ed1daf0bf`.

- [ ] **Step 6: Start the real server and prove OMP semantic navigation**

Start `tools/start_godot_lsp.sh` as a supervised foreground process. Wait until Godot completes project initialization and port 6015 accepts connections. Do not start a Windows Godot editor concurrently.

Reload the OMP workspace LSP configuration, then issue these exact LSP checks:

1. `status` with no file.
2. `definition` with `file: "core/application/game_coordinator.gd"`, `line: 48`, and `symbol: "GameSession"`.
3. `references` with `file: "core/domain/game_session.gd"`, `line: 63`, and `symbol: "submit"`.
4. `diagnostics` with `file: "core/application/game_coordinator.gd"`.

Expected:

- Status reports `godot-gdscript` active.
- Definition resolves to `core/domain/game_session.gd:1`.
- References include `core/application/game_coordinator.gd:80` and relevant tests.
- Diagnostics return `OK`.
- Godot logs contain no `language server does not support nonlocal files` message.

Stop the supervised Linux Godot process before continuing.

- [ ] **Step 7: Commit the working transport boundary**

Inspect the staged paths explicitly; do not stage the existing scene change:

```bash
git add .omp/lsp.json tools/start_godot_lsp.sh
git diff --cached --check
git diff --cached --name-only
```

Expected staged paths:

```text
.omp/lsp.json
tools/start_godot_lsp.sh
```

Commit:

```bash
git commit -m "build: add Godot LSP integration for OMP"
```

---

### Task 2: Token-efficient agent policy and developer guidance

**Files:**
- Create: `.omp/AGENTS.md`
- Modify: `docs/setup/godot-development.md:1-50`

**Interfaces:**
- Consumes: `tools/start_godot_lsp.sh`, `.omp/lsp.json`, the existing `tools/test.ps1` Windows gate, and OMP's native project-context discovery.
- Produces: always-loaded project guidance and a human-operable installation/lifecycle/recovery procedure.

- [ ] **Step 1: Add the concise project instruction file**

Create `.omp/AGENTS.md`:

```markdown
# Godot development

- Use Godot 4.7.2 and typed GDScript.
- First-party code is under `app`, `core`, `features`, and `tests`.
- `addons/gut` is vendored; do not inspect or edit it unless explicitly required.
- For `.gd` tasks, use narrow LSP definition, references, hover, symbols, and rename operations before broad searches or whole-file reads.
- Query specific members rather than broad classes unless performing a class-wide change.
- Read only the source ranges required for the change.
- Before modifying an exported symbol, inspect its LSP references.
- Run file-scoped diagnostics on changed `.gd` files once after each logical edit batch. Do not use workspace diagnostics with `file: "*"` for Godot.
- LSP is semantic feedback, not final verification. Run the relevant GUT coverage and finish significant changes with `tools/test.ps1`.
```

Keep this file self-contained and short. Do not import the README, design specification, or implementation plans into the startup context.

- [ ] **Step 2: Document native Linux installation**

Insert the following section immediately before `## Android SDK and JDK` in `docs/setup/godot-development.md`, preserving the existing Windows pinned-toolchain section:

````markdown
## OMP and GDScript LSP in WSL

OMP runs inside WSL, so its GDScript language server must use the official
Godot 4.7.2 Linux standard build against the local WSL project path. The Linux
binary is an LSP companion only; the pinned Windows binary remains authoritative
for `tools/test.ps1` and exports.

Install the Linux binary outside the repository:

```bash
mkdir -p "$HOME/.local/opt/godot-4.7.2" "$HOME/.local/bin"
curl -L --fail \
  -o /tmp/Godot_v4.7.2-stable_linux.x86_64.zip \
  https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
printf '%s  %s\n' \
  'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4' \
  '/tmp/Godot_v4.7.2-stable_linux.x86_64.zip' \
  | sha256sum -c -
unzip -o /tmp/Godot_v4.7.2-stable_linux.x86_64.zip \
  -d "$HOME/.local/opt/godot-4.7.2"
chmod 0755 "$HOME/.local/opt/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"
ln -sfn \
  "$HOME/.local/opt/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64" \
  "$HOME/.local/bin/godot-4.7.2"
rm -f /tmp/Godot_v4.7.2-stable_linux.x86_64.zip
"$HOME/.local/bin/godot-4.7.2" --version
```

The checksum command must pass. The final version output must be
`4.7.2.stable.official.ed1daf0bf`, matching the Windows build. Do not commit
the executable or downloaded archive.
````

- [ ] **Step 3: Document the operating lifecycle and recovery path**

Append this content to the same WSL LSP section:

````markdown
### Run the LSP service

Start the service before the first OMP LSP operation:

```bash
# Terminal 1, from the repository root
./tools/start_godot_lsp.sh

# Terminal 2, from the repository root
omp
```

Port `6015` is reserved for the WSL-native Godot LSP service. The launcher
stays in the foreground; stop it with Ctrl-C before running Windows import,
`tools/test.ps1`, or exports. Do not run simultaneous Linux and Windows
editor/import processes against the same `.godot` directory.

If OMP attempted to initialize before Godot was ready, start the launcher and
invoke an OMP workspace LSP reload with `file: "*"`, or start a new OMP
session. A `nonlocal files` error, a self-hiding global-class diagnostic, or a
cross-file definition that does not resolve indicates connection to the wrong
Godot process or filesystem namespace.

LSP diagnostics provide fast parser and type feedback. They do not verify scene
paths, signals, persistence, runtime interaction, or exports; use the existing
GUT and release gates for those behaviors.
````

- [ ] **Step 4: Verify documentation and project-context scope**

Start a fresh OMP session from the repository root and inspect discovered project context.

Expected:

- `.omp/AGENTS.md` is the selected native project context.
- The complete README, old implementation plan, and game design spec are not injected through imports.
- `.omp/lsp.json` still configures only `.gd` files and port 6015.
- `addons/gut` remains on disk but the instructions exclude it from ordinary investigation.

Read the rendered setup section once and confirm that every command is copy-pasteable from WSL without placeholder paths.

- [ ] **Step 5: Run final integration and behavioral verification**

Start `tools/start_godot_lsp.sh`, reload OMP LSP, and repeat:

- Definition from `GameSession` in `core/application/game_coordinator.gd:48` to `core/domain/game_session.gd:1`.
- References for `submit` at `core/domain/game_session.gd:63`, including `core/application/game_coordinator.gd:80`.
- Diagnostics on `core/application/game_coordinator.gd`, expected `OK`.

Stop Linux Godot. Then run the authoritative Windows gate:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/test.ps1
```

Expected: all existing GUT tests pass with exit code 0.

Finally run:

```bash
git diff --check
git status --short
```

Expected:

- No downloaded Linux binary, zip archive, log, temporary probe, or generated `.godot` content is newly tracked.
- The pre-existing `features/settings/settings_view.tscn` modification remains untouched.
- Only the planned instruction and documentation files remain uncommitted for this task.

- [ ] **Step 6: Commit the operating policy and documentation**

Stage only the planned files:

```bash
git add .omp/AGENTS.md docs/setup/godot-development.md
git diff --cached --check
git diff --cached --name-only
```

Expected staged paths:

```text
.omp/AGENTS.md
docs/setup/godot-development.md
```

Commit:

```bash
git commit -m "docs: define token-efficient Godot LSP workflow"
```

## Completion criteria

Before calling the work complete, confirm every acceptance item in `docs/superpowers/specs/2026-09-09-omp-godot-lsp-design.md` against captured command or LSP output. The final branch must contain exactly the project configuration, foreground launcher, concise native instructions, and setup documentation described here; it must not contain a downloaded engine, third-party bridge, new package manifest, gameplay change, test rewrite, or modification to the user's existing scene work.
