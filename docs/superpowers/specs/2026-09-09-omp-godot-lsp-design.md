# OMP Godot LSP Tooling Design

**Date:** 2026-09-09
**Status:** Proposed for user verification
**Project:** Utera Ti Dechko
**Engine:** Godot 4.7.2-stable, standard build, typed GDScript

## Summary

Add project-local OMP language-server configuration for typed GDScript without changing the game's runtime or release toolchain. OMP will connect over stdio to `/usr/bin/nc`; `nc` will proxy the byte stream to a dedicated Godot 4.7.2 Linux editor process running inside WSL on TCP port 6015.

The Linux process is required because the repository lives on the WSL filesystem. The existing Windows Godot process opens that path through `\\wsl.localhost\Ubuntu-24.04\...`, and its GDScript language server rejects those documents as nonlocal files. Windows Godot remains authoritative for the existing automated test and export commands.

## Goals

- Give OMP semantic GDScript definition, reference, hover, symbol, rename, and diagnostic operations.
- Keep client and server file URIs in the same WSL filesystem namespace.
- Reduce token use by preferring narrow semantic queries and range reads over broad searches and whole-file reads.
- Preserve the pinned Godot 4.7.2 version and existing Windows test/export workflow.
- Keep the integration project-local, dependency-light, explicit, and reversible.
- Document a safe lifecycle that avoids simultaneous Linux and Windows editor/import processes against the same `.godot` directory.

## Non-goals

- Changing gameplay, scenes, resources, exports, or production dependencies.
- Replacing GUT or `tools/test.ps1` with LSP diagnostics.
- Providing semantic support for `.tscn`, `.tres`, or `.gdshader` files.
- Moving the repository from WSL to Windows storage.
- Adding a third-party Node or Rust LSP bridge while the installed `nc` transport is sufficient.
- Adding a custom OMP skill or rigid workflow before repeated use demonstrates a need for one.
- Automatically downloading or committing the Godot executable into the repository.

## Current state and constraints

- OMP has no configured language server for this project.
- OMP custom language servers are spawned as stdio commands.
- Godot 4.7.2 exposes GDScript LSP over TCP through `--lsp-port`; it does not provide the proposed `--lsp` stdio mode.
- `/usr/bin/nc` is installed in WSL and successfully bridges OMP stdio to Godot TCP.
- The official Linux and existing Windows executables both report `4.7.2.stable.official.ed1daf0bf`.
- The official Linux archive SHA-256 is `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
- The repository contains 63 first-party GDScript files and approximately 7,433 GDScript lines including tests. `addons/gut` is vendored and normally outside agent investigation scope.

## Architecture

```mermaid
flowchart LR
    OMP[OMP LSP client in WSL] -->|stdio| NC[/usr/bin/nc]
    NC -->|TCP 127.0.0.1:6015| Godot[Godot 4.7.2 Linux headless editor]
    Godot -->|indexes local paths| Repo[WSL project workspace]
    Windows[Godot 4.7.2 Windows] -->|tests and exports only| Repo
```

Only one Godot editor/import owner should operate on the project at a time. Linux Godot owns the workspace during OMP semantic work. It is stopped before Windows import, full tests, or exports.

## Components

### Native Linux Godot prerequisite

Install the official standard Linux 4.7.2 binary outside the repository and expose it as:

```text
~/.local/bin/godot-4.7.2
```

The installation procedure must verify the official SHA-256 before extraction. The binary is a developer prerequisite, not a checked-in artifact.

### `tools/start_godot_lsp.sh`

A foreground launcher with one responsibility: start the matching Linux Godot editor for this repository's LSP service.

Contract:

- Resolve the repository root relative to the script, not the caller's working directory.
- Use `${GODOT_LSP_BINARY:-$HOME/.local/bin/godot-4.7.2}`.
- Use fixed port `6015`.
- Fail with a concise error when the binary is missing or not executable.
- Use `exec` so signals and exit status belong to Godot.
- Start `--headless --editor` with the resolved project path and fixed `--lsp-port`.
- Write Godot logs to `${GODOT_LSP_LOG:-/tmp/utera-ti-dechko-godot-lsp.log}`.
- Remain in the foreground; Ctrl-C stops the service. Do not daemonize or kill unrelated Godot processes.

### `.omp/lsp.json`

Register one custom server:

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

A fixed nondefault port prevents accidental connection to a Windows Godot editor using the default port 6005. The project uses OMP's existing `lsp.lazy`, `lsp.shared`, and diagnostic defaults; no `.omp/config.yml` is needed.

### `.omp/AGENTS.md`

Provide concise, always-applicable project guidance:

- First-party roots are `app`, `core`, `features`, and `tests`.
- `addons/gut` is vendored and excluded unless explicitly in scope.
- Use narrow LSP navigation before broad searches or whole-file reads.
- Inspect references before exported-symbol changes.
- Diagnose changed `.gd` files once per logical edit batch.
- Treat LSP as fast semantic feedback, never as final behavioral verification.
- Run the relevant GUT coverage and finish significant changes with `tools/test.ps1`.

This remains a context file rather than a custom workflow. It lets the agent skip inapplicable steps while preserving the default LSP-first policy.

### Developer documentation

Extend `docs/setup/godot-development.md` with:

- Official Linux download and checksum.
- One-time installation commands.
- Launcher usage and Ctrl-C shutdown.
- The port 6015 requirement.
- The Linux-editing/Windows-verification lifecycle.
- Recovery after starting Godot too late: restart or reload the OMP LSP configuration.
- A warning not to run simultaneous cross-platform editor/import processes against `.godot`.

## Token-efficient operating sequence

1. Locate a narrow symbol or exact file.
2. Use definition or hover to identify the relevant contract.
3. Use references on the specific member before changing shared APIs.
4. Read only the source range needed for the change.
5. Apply surgical edits.
6. Run file-scoped diagnostics once for changed `.gd` files.
7. Run behavioral tests independently of LSP.

Broad class reference searches remain exceptional: they can return hundreds of locations and consume more context than a targeted query. OMP workspace diagnostics with `file: "*"` are not used for Godot because that mode only recognizes selected non-Godot project types.

## Error handling

- Missing Linux binary: launcher exits nonzero and prints the expected path plus `GODOT_LSP_BINARY` override.
- Port unavailable: Godot reports the bind failure in the foreground and log; stop the conflicting process rather than silently moving the launcher away from `.omp/lsp.json`.
- OMP started before Godot: start the launcher, then reload the workspace LSP configuration or start a fresh OMP session.
- Definition resolves no project symbol or diagnostics report a class hiding itself: stop and confirm OMP connected to Linux Godot on port 6015 rather than Windows Godot on 6005.
- Windows verification needed: stop the foreground Linux server before invoking `tools/test.ps1`, import, or export commands.

## Verification

The integration is accepted when all of the following are observed:

1. `bash -n tools/start_godot_lsp.sh` succeeds.
2. The launcher rejects a nonexistent `GODOT_LSP_BINARY` with a nonzero exit and actionable message.
3. The real launcher starts Linux Godot 4.7.2 and listens on port 6015.
4. OMP reports `godot-gdscript` configured and starts it on demand.
5. Definition on `GameSession` at `core/application/game_coordinator.gd:48` resolves to `core/domain/game_session.gd:1`.
6. A narrow references query returns project callsites.
7. Diagnostics for `core/application/game_coordinator.gd` return `OK`.
8. After stopping Linux Godot, `tools/test.ps1` passes under the existing Windows toolchain.
9. No downloaded binary, generated log, temporary probe, or `.godot` output is newly tracked.

## Security and maintenance

- Download only from the official Godot release and verify its pinned checksum.
- Keep the executable outside the repository.
- Bind the language server to loopback through Godot's default behavior; do not expose it to the network.
- Use the absolute `/usr/bin/nc` path to avoid PATH shadowing.
- Keep port and version values centralized in the small launcher/config pair; do not add package manifests solely for an LSP bridge.
- Reassess the bridge only when a project-compatible stable Godot release includes native stdio LSP support.
