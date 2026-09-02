# УТЕРА ТИ ДЕЧКО

Offline, unlimited Serbian Cyrillic word guessing for Windows, Web, and Android. One Godot 4.7.2 project supports 1, 2, 4, and 8 simultaneous boards and saves the complete four-mode game bundle locally.

The project uses typed GDScript, the Compatibility renderer, GUT 9.7.0, a threadless Web build, and responsive desktop/mobile presentation.

## Development

- [Godot development and export setup](docs/setup/godot-development.md)
- [Release smoke checklist and latest evidence](docs/testing/release-smoke-checklist.md)
- [Approved design specification](docs/superpowers/specs/2026-08-30-utera-ti-dechko-design.md)
- [Implementation plan](docs/superpowers/plans/2026-08-30-utera-ti-dechko.md)

Run the complete automated gate from PowerShell:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/test.ps1
```

Generated builds belong under `builds/` and are intentionally not tracked.
