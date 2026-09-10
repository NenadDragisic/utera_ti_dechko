# УТЕРА ТИ ДЕЧКО

Offline, unlimited Serbian Cyrillic word guessing for Windows, Web, and Android. One Godot 4.7.2 project supports 1, 2, 4, and 8 simultaneous boards and saves the complete four-mode game bundle locally.

The project uses typed GDScript, the Compatibility renderer, GUT 9.7.0, a threadless Web build, and responsive desktop/mobile presentation.

## Development

- [Godot development and export setup](docs/setup/godot-development.md)
- [Release smoke checklist and latest evidence](docs/testing/release-smoke-checklist.md)
- [Approved design specification](docs/superpowers/specs/2026-08-30-utera-ti-dechko-design.md)
- [Implementation plan](docs/superpowers/plans/2026-08-30-utera-ti-dechko.md)

### OMP with GDScript language support

From WSL, complete the one-time [Linux Godot LSP setup](docs/setup/godot-development.md#omp-and-gdscript-lsp-in-wsl), close any Windows Godot editor, then run:

```bash
./tools/omp_with_godot_lsp.sh
```

The wrapper verifies that Windows Godot is not running, starts the matching Linux Godot language server, waits until it is ready, launches OMP from the project root, and stops Linux Godot when OMP exits. Use plain `omp` for work that does not need GDScript language operations; it does not start Godot.

Never run Linux and Windows Godot editor/import processes against this repository at the same time. Exit the wrapped OMP session before using Windows Godot, exports, or `tools/test.ps1`.

Verify the wrapper lifecycle from WSL:

```bash
tests/tools/test_omp_with_godot_lsp.sh
```

Run the complete automated gate from PowerShell:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/test.ps1
```

Generated builds belong under `builds/` and are intentionally not tracked.
