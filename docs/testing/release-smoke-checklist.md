# Release smoke checklist

## Record

- Release candidate: Task 14 cross-platform exports and responsive release fixes
- Date: 2026-09-02
- Branch: `feature/utera-ti-dechko`
- Godot: `4.7.2.stable.official.ed1daf0bf`
- Renderer: Compatibility (`gl_compatibility`) for desktop and mobile
- Evidence owner: Codex execution environment; no human operator was available unless a row explicitly says otherwise

Evidence classes are deliberately separate:

- **AUTO** — source-level or headless automated test.
- **EXPORT** — exporter/artifact/package inspection; does not prove launch or usability.
- **RUNTIME** — the exported binary actually started; noninteractive launch alone does not prove interaction.
- **BROWSER/EMU** — scripted interaction in a real browser or Android emulator.
- **MANUAL** — a human directly observed and operated the UI. Never infer this from another class.

Statuses: `PASS`, `FAIL`, `BLOCKED`, or `NOT RUN`. Every `PASS` must name exact evidence.

## Environment and artifact evidence

| Class | Check | Environment | Status | Evidence |
|---|---|---|---|---|
| AUTO | Word import count/validity/fingerprint | Python 3, WSL | PASS | 18,064 words; 0 invalid; 0 duplicate; SHA-256 fingerprint `0152ee75650f9fd2568ca4ad6c4c93db5eb3d01758d0ec30fe158063847b7fed`. |
| AUTO | Full GUT gate | Windows Godot 4.7.2 headless | PASS | `tools/test.ps1`: 24 scripts, 153/153 tests, 3,369 assertions, exit 0. |
| AUTO | Clean editor import/parser/resource gate | Windows Godot 4.7.2 headless | PASS | Absolute Windows-resolved project path; `--editor --quit` completed with no parser/resource error, exit 0. |
| EXPORT | Windows x86_64 release | Godot official templates | PASS | `utera-ti-dechko.exe`, 109,142,016 bytes, SHA-256 `797844cc4adc5cf03e9751b0042e9db81c058d0998a8976f04b461cd92c608fe`; PCK 350,208 bytes, SHA-256 `98d4763c03128614e0f5e5782a6bbf38287febc68b322994769af305172960d6`. |
| EXPORT | Threadless Web release | Godot official single-threaded Web template | PASS | `variant/thread_support=false`; runtime requests `godot.web.template_release.wasm32.nothreads.wasm`. HTML `6a85f2f036577a93d246f201ed55ceaab04e0e6dfe9436ad880a5f0686955f67`; PCK `98d4763c03128614e0f5e5782a6bbf38287febc68b322994769af305172960d6`; WASM `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`; JS `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`. |
| EXPORT | Android debug APK (`arm64-v8a`, `x86_64`) | Existing Android SDK/JDK | PASS | APK 57,177,293 bytes, SHA-256 `7fc3f0c041b5cde30e7dd5a29bf9b13beb1b85c0bb4c4d689cd39489148b54f2`; archive contains both `lib/arm64-v8a/libgodot_android.so` and `lib/x86_64/libgodot_android.so`. |
| EXPORT | Production packs exclude `.git`, `.superpowers`, `builds`, `tests`, `tools`, `docs`, `addons/gut` | Final `--export-pack` ZIP inventory | PASS | 99 entries; `data/baza_words.txt` exactly once; forbidden path matches 0. Audit ZIP SHA-256 `153040bea8cb3c365aebe7006bd377283121e06079c55fca5be78a5829536ae8`. |
| RUNTIME | Windows exported release starts | Windows 11 `10.0.26200.9168`, NVIDIA Compatibility | PASS | Two isolated-profile launches; runtime logs report no SCRIPT ERROR/ERROR/FATAL. |
| BROWSER/EMU | Web release starts over local HTTP, desktop viewport | Headless Chrome 152.0.7977.65 on Windows | PASS | 1440×900 canvas, status overlay absent, zero Runtime/Log errors. |
| BROWSER/EMU | Web release starts over local HTTP, 390×844 and 844×390 | Chrome 152 responsive/CDP | PASS | Exact 390×844 and 844×390 canvas measurements; paired RED/GREEN screenshots demonstrate removal of old 27.1%/43.3% root down-scaling; zero runtime errors. |
| BROWSER/EMU | Android APK installs and starts | AVD `FU-YT-Latest`, Android 17/API 37, `sdk_gphone16k_x86_64`, 1080×2400@420dpi | PASS | Final APK installed; process stayed alive; logcat reports OpenGL ES 3.1 Compatibility and no Godot SCRIPT ERROR/ERROR/FATAL. |

## Functional smoke matrix

Use a fresh isolated save for the first row on each platform, then preserve that profile for resume/reload checks. Record the exact browser version, emulator/device/API, orientation, and input method.

| Class | Platform | Scenario | Status | Evidence or blocker |
|---|---|---|---|---|
| MANUAL | Windows | Fresh launch; human-like invalid fifth letter turns the active rows red; erase clears red; type a valid guess; submit; switch modes; return and restore the prior input/progress. | NOT RUN | Requires direct human mouse/keyboard observation (Task 10 ledger). |
| MANUAL | Windows | Finish modes 1 and 8; review score/answers/statistics; copy private share text; change dark/light/system theme; restart and resume. | NOT RUN | Requires direct human play. |
| MANUAL | Windows | Enable accessibility on-screen keyboard on a wide mode-8 board; verify four-column/multi-board layout remains wide and manual-copy fallback is selectable/usable. | NOT RUN | Requires direct human accessibility usability check (Task 12 ledger). |
| MANUAL | Windows | With a native screen reader, inspect board/cell/mode/navigator/action names and announcement quality; keyboard focus order and visible focus remain logical. | NOT RUN | Requires installed/operated assistive technology (Task 13 ledger). |
| MANUAL | Windows | Pointer-test notice close target, observe 150 ms invalid/reveal/solved motion, then enable reduced motion and verify synchronous final states. | NOT RUN | Requires direct perception and pointer use (Task 13 ledger). |
| MANUAL | Web desktop | Repeat valid/invalid, finish 1/8, mode switch, copy/fallback, theme, reset cancel/confirm; reload same origin and resume from IndexedDB. | NOT RUN | Requires direct human browser play. |
| MANUAL | Web mobile responsive | At 390×844 and 844×390, collapse/reopen keyboard, swipe boards, rotate viewport, keep active row visible, reload and resume. | NOT RUN | Requires direct human responsive-mode play. |
| MANUAL | Physical Android | On each keyboard row, horizontally drag from the first key to and tap final `Ш`, `Ч`, `М`; verify one correct input with no miss, duplicate, board swipe, or stuck scroll. Repeat after collapse/reopen and portrait↔landscape rotation. | NOT RUN | Physical-device reliability requirement from Task 11. Emulator evidence cannot close this row. |
| MANUAL | Physical Android | Finish modes 1 and 8; mode switch; app restart/resume; native clipboard; theme; reset cancel/confirm; active row remains fully visible after progressed mode-8 rotation. | NOT RUN | Requires a physical device and direct human observation. |
| MANUAL | Physical Android | Native accessibility names and screen-reader announcement quality; notice close pointer target; motion feel and reduced-motion behavior. | NOT RUN | Requires physical device assistive technology/direct perception. |

The `MANUAL` Windows rows remain NOT RUN even though the Windows host was
available: the release run was operated by deterministic Win32 input automation,
not a human. The physical-Android rows remain NOT RUN because only an emulator
was attached. No native screen reader was installed or operated.

## Scripted exported-runtime matrix

These rows may support the functional matrix but do not replace `MANUAL` rows.

| Class | Platform | Scripted scenario | Status | Evidence |
|---|---|---|---|---|
| RUNTIME | Windows | Launch final release build and remain alive through startup without parser/resource/runtime errors. | PASS | `windows_interaction.ps1` ran two final exported releases with isolated APPDATA and reported `runtime_errors=0`. |
| RUNTIME | Windows | Invalid-red → erase → valid submit → mode switch/restore → restart/resume (Task 10 ledger). | PASS | Posted physical-key scan codes to the final export. Captures `windows-invalid-red.png`, `windows-valid-submit.png`, `windows-mode2-input.png`, `windows-mode1-restored.png`, and `windows-restart-resume.png`; script reported every state PASS. This is scripted, not MANUAL evidence. |
| BROWSER/EMU | Web | Serve through local HTTP; load 1440×900, 390×844, and 844×390; capture console and geometry. | PASS | Chrome CDP measured exact canvas dimensions, `/userfs` IndexedDB, missing startup status overlay, and 0 runtime errors. `web-green-*` captures recorded desktop/mobile and game layouts. |
| BROWSER/EMU | Web | Invalid red → erase → valid `АВАЛА` submit → same-origin reload/resume. | PASS | Final exported Web interaction captures `web-desktop-invalid-red.png`, `web-desktop-valid-submit.png`, `web-desktop-indexeddb-resume.png`; IndexedDB `/userfs`; 0 runtime errors. |
| BROWSER/EMU | Android | Install/launch, collapse/reopen, portrait/landscape, restart/resume, inspect process/logcat. | PASS | Final AVD captures `android-green-keyboard-{collapsed,reopened}.png`, `android-green-rotation-*`, and `android-green-restart-mode8-resumed.png`; `ШЧМ` survived force-stop/relaunch. |
| BROWSER/EMU | Android | Drag each hidden keyboard row starting over a key to final `Ш`, `Ч`, `М`; exactly one input each and no board swipe. | PASS | ADB touch drags exposed all row ends in `android-green-keyboard-rows-scrolled.png`; one tap per final key produced exactly three board cells `ШЧМ` in `android-green-final-keys-exactly-once.png`; board navigator remained on 1. Synthetic regression is `test_touch_drag_starting_over_a_key_reaches_each_final_key_without_typing`. Physical repetition remains MANUAL. |
| BROWSER/EMU | Android | Expanded 2400×1080@420dpi landscape retains one complete active row and navigation. | PASS | Root-level regression uses logical 914×411 and verifies hidden header/footer, zero vertical shell margins, and complete active row. `android-green-mode8-landscape-expanded.png` and `android-green-rotation-landscape-expanded.png` show the full row above the keyboard; system back/Home path remains implemented and tested. |
| AUTO | Root content scale RED/GREEN | Godot root Window + exported Chrome | PASS | RED: root remained 1440×900, causing mobile scale factors 390/1440=27.1% and 390/900=43.3%. GREEN: `test_root_window_keeps_web_and_dense_android_at_readable_content_scale` proves Web 390×844/844×390, desktop 1440×900, and Android 411×914/914×411; Chrome screenshots confirm readable native geometry. |
| AUTO | Desktop accessibility-keyboard layout (Task 12 ledger) | GUT scene geometry | PASS | `test_desktop_onscreen_keyboard_preserves_wide_eight_board_layout` retains the wide four-column board arrangement. Actual keyboard/mouse fallback usability remains MANUAL. |
| AUTO | Accessibility names, notice target, motion/reduced motion (Task 13 ledger) | GUT scene/accessibility suites | PASS | Accessible-name/focus paths, 44px notice close target, 140ms restrained motion hook, and reduced-motion synchronous states pass. Native screen-reader quality and perceived motion feel remain MANUAL. |
| AUTO | Debug-only bundle audit | Final debuggable APK private save, metadata-only output | PASS | Without printing answers: `count=15`, `distinct=15`, `lengths=[5]`; final mode-8 input length was 3. `rg` found no debug answer dump/print in production source; all final artifacts were rebuilt after temporary investigation. |

## Acceptance-criteria trace

| Design acceptance criterion | Evidence |
|---|---|
| 1. Four modes and audited attempt limits | AUTO: `test_mode_sizes_assign_their_attempt_limits`; coordinator/session scene suites. |
| 2. Fresh bundle has 15 distinct answers | AUTO: shuffle-bag/session-factory tests; temporary debug exported-runtime audit above. |
| 3. Five-letter cap and mirroring | AUTO: game-session and coordinator tests. |
| 4. Invalid red and blocked submission | AUTO: game-session/board/coordinator tests; MANUAL platform rows remain required for visual feel. |
| 5. Duplicate-letter evaluation | AUTO: guess-evaluator suite. |
| 6. Mode switch and persistence | AUTO coordinator/progress tests; Windows exported restart, Web IndexedDB reload, and Android force-stop/relaunch all passed above. |
| 7. New game retention/abandonment semantics | AUTO: coordinator/settings/reset tests; MANUAL cancel/confirm rows remain required. |
| 8. Windows/Web/Android Obsidian Focus layout | AUTO geometry/theme suites plus exported Chrome and emulator captures; MANUAL visual judgment remains open. |
| 9. Mobile readable focus board and navigator | AUTO root/mobile scene suites and Android emulator portrait/expanded-landscape captures; physical Android usability remains open. |
| 10. Private sharing and Web fallback | AUTO share/results/Home suites; browser clipboard/fallback row remains required. |
| 11. Automated tests pass headlessly | AUTO final full gate: 153/153, 3,369 assertions. |
| 12. All three exports launch and complete a smoke game | All three launch and scripted partial-play/resume paths pass. Full human completion of modes 1 and 8 on every target was NOT RUN and is an explicit release concern, not silently promoted from automation. |

## Release hygiene

- [x] Final source tree passes `git diff --check`.
- [x] Final full GUT suite is fresh and green.
- [x] Final clean editor import/parser/resource gate exits 0.
- [x] All three final artifacts are rebuilt after removal of any debug-only state dump.
- [x] Artifact existence, size, and SHA-256 are recorded above.
- [x] Export pack inventory contains none of the seven excluded development paths.
- [x] `git status --short` contains no tracked build, cache, save, credential, keystore, or local SDK file.
- [x] Genuinely manual gaps remain visibly `NOT RUN`; automated evidence is not promoted to manual evidence.

## Deferred-item disposition

- Task 4 minor: `BoardState.rows` remains publicly mutable. Final review confirmed
  this is unchanged and nonblocking; no release behavior depends on widening that
  API further. A future encapsulation refactor should preserve serialization and
  evaluator behavior.
- Task 10: strongest available Windows exported-runtime automation PASS; genuine
  human observation remains NOT RUN.
- Task 11: emulator row-drag, final keys, collapse/reopen, rotation, active-row
  visibility, and restart PASS; physical device repetition remains NOT RUN.
- Task 12: automated wide-layout PASS; human manual-fallback usability NOT RUN.
- Task 13: automated semantics/targets/motion PASS; native screen-reader quality
  and perceived 150ms/reduced-motion feel NOT RUN.
