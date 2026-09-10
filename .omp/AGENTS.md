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
