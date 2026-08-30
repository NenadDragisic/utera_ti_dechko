# Utera Ti Dechko Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved offline, unlimited Serbian Cyrillic multi-board word game for Windows, Web, and Android in Godot.

**Architecture:** A feature-oriented Godot project keeps pure typed-GDScript domain objects under `core/domain`, orchestration and ports under `core/application`, adapters under `core/infrastructure`, and reusable `Control` scenes beside their feature scripts. `AppRoot` is the composition root; it owns dependencies and navigation, while scenes only render view state and emit typed player-intent signals.

**Tech Stack:** Godot 4.7.2-stable standard build, typed GDScript, Compatibility renderer, GUT 9.7.0, UTF-8 text data, JSON persistence, Windows/Web/Android export templates.

**Spec:** `docs/superpowers/specs/2026-08-30-utera-ti-dechko-design.md`

## Global Constraints

- Use Godot 4.7.2-stable; do not silently continue with the installed 4.5 executable.
- Use typed GDScript throughout; no C#, GDExtension, native plugins, server, analytics, ads, or audio.
- Configure the Compatibility renderer, `canvas_items` stretching, and expanded aspect handling.
- Keep all gameplay rules and persistence serialization outside scene scripts.
- Do not use an autoload for mutable game state; `AppRoot` is the composition root.
- The four modes are 1, 2, 4, and 8 boards with 6, 7, 9, and 13 attempts.
- Every answer and accepted guess contains exactly five letters from `АБВГДЂЕЖЗИЈКЛЉМНЊОПРСТЋУФХЦЧЏШ`.
- A new bundle contains 15 distinct answers and replaces every mode; abandoned unfinished modes are not losses.
- Windows and wide Web use direct physical input with no permanent keyboard; Android and narrow Web use the collapsible keyboard sheet and focus navigator.
- Display `УТЕРА ТИ ДЕЧКО` at top left and `Ставља у погон: ПрслаФабрика` at bottom left. Do not add the removed explanatory captions or info cards.
- Use `user://save_v1.json`, validated versioned JSON, atomic replacement, and recovery of invalid saves.
- Pin GUT 9.7.0 as a development-only dependency and exclude it from production exports.
- Run automated tests headlessly after every task and smoke-test all three target exports before release.

## File map

```text
res://
├── project.godot
├── icon.svg
├── app/
│   ├── app_root.gd
│   ├── app_root.tscn
│   ├── app_theme.tres
│   ├── app_theme_light.tres
│   └── design_tokens.gd
├── core/
│   ├── domain/
│   │   ├── answer_shuffle_bag.gd
│   │   ├── board_state.gd
│   │   ├── game_bundle.gd
│   │   ├── game_session.gd
│   │   ├── guess_evaluator.gd
│   │   ├── guess_row.gd
│   │   ├── letter_mark.gd
│   │   ├── settings.gd
│   │   ├── statistics.gd
│   │   └── word_pool.gd
│   ├── application/
│   │   ├── clipboard_port.gd
│   │   ├── game_coordinator.gd
│   │   ├── progress_service.gd
│   │   ├── random_port.gd
│   │   ├── save_repository_port.gd
│   │   ├── session_factory.gd
│   │   └── share_service.gd
│   └── infrastructure/
│       ├── baza_word_repository.gd
│       ├── godot_clipboard_adapter.gd
│       ├── godot_random_source.gd
│       ├── platform_capabilities.gd
│       └── user_save_repository.gd
├── data/
│   ├── baza_words.txt
│   └── game_config.tres
├── features/
│   ├── common/{notice_banner.gd,notice_banner.tscn}
│   ├── gameplay/{board_view.gd,board_view.tscn,game_screen.gd,game_screen.tscn,input_mapper.gd,keyboard_view.gd,keyboard_view.tscn}
│   ├── home/{home_screen.gd,home_screen.tscn}
│   ├── results/{results_view.gd,results_view.tscn,statistics_view.gd,statistics_view.tscn}
│   └── settings/{confirm_new_game_dialog.gd,confirm_new_game_dialog.tscn,settings_view.gd,settings_view.tscn}
├── tests/
│   ├── application/
│   ├── domain/
│   ├── doubles/
│   ├── infrastructure/
│   ├── scenes/
│   └── test_smoke.gd
└── tools/
    ├── extract_baza.py
    ├── run_godot.ps1
    ├── test.ps1
    └── validate_words.py
```

---

### Task 1: Reproducible Godot project and test harness

**Files:**
- Create: `project.godot`
- Create: `app/app_root.gd`
- Create: `app/app_root.tscn`
- Create: `tools/run_godot.ps1`
- Create: `tools/test.ps1`
- Create: `tests/test_smoke.gd`
- Create: `addons/gut/**` from the GUT 9.7.0 release
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Godot 4.7.2 at `C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe`.
- Produces: `AppRoot` main scene and repeatable `tools/test.ps1` headless test entry point.

- [ ] **Step 1: Install and verify the exact editor/runtime**

Download the official `Godot_v4.7.2-stable_win64.exe.zip`, extract it to `C:\Users\Nenad\Desktop\Godot 4.7.2`, and verify:

```powershell
& 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --version
```

Expected: output begins `4.7.2.stable`. Keep 4.5 installed, but do not use it for this project.

- [ ] **Step 2: Write the failing smoke test and runners**

```gdscript
# tests/test_smoke.gd
extends GutTest

func test_app_root_can_be_instantiated() -> void:
    var root := load("res://app/app_root.tscn").instantiate()
    assert_not_null(root)
    root.free()
```

```powershell
# tools/test.ps1
$ErrorActionPreference = 'Stop'
$Godot = 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $Godot --headless --path (Resolve-Path "$PSScriptRoot\..") -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
exit $LASTEXITCODE
```

```powershell
# tools/run_godot.ps1
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs)
$ErrorActionPreference = 'Stop'
$Godot = 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $Godot --path (Resolve-Path "$PSScriptRoot\..") @GodotArgs
exit $LASTEXITCODE
```

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1`

Expected: FAIL because `res://app/app_root.tscn` does not exist.

- [ ] **Step 3: Add the minimal configured project and scene**

Set `run/main_scene` to `res://app/app_root.tscn`, renderer to `gl_compatibility`, window base size to 1440×900, stretch mode to `canvas_items`, aspect to `expand`, and locale fallback to Serbian Cyrillic. Create a `Control` root with full-rect anchors:

```gdscript
# app/app_root.gd
class_name AppRoot
extends Control

func _ready() -> void:
    set_process_unhandled_key_input(true)
```

- [ ] **Step 4: Pin GUT and prove the harness passes**

Vendor only `addons/gut` from the 9.7.0 tag, enable the plugin in `project.godot`, and add `/addons/gut/` to export exclusions rather than `.gitignore`.

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1`

Expected: 1 test, 1 passing, exit code 0.

- [ ] **Step 5: Commit the bootstrap**

```bash
git add .gitignore project.godot app addons/gut tests/test_smoke.gd tools/run_godot.ps1 tools/test.ps1
git commit -m "build: bootstrap Godot project and GUT"
```

### Task 2: Import and validate the audited `baza` word pool

**Files:**
- Create: `tools/extract_baza.py`
- Create: `tools/validate_words.py`
- Create: `data/baza_words.txt`
- Create: `core/domain/word_pool.gd`
- Create: `core/infrastructure/baza_word_repository.gd`
- Test: `tests/domain/test_word_pool.gd`
- Test: `tests/infrastructure/test_baza_word_repository.gd`

**Interfaces:**
- Produces: `WordPool.from_entries(entries: PackedStringArray) -> WordPool`, `contains(word: String) -> bool`, `answers() -> PackedStringArray`, `fingerprint() -> String`; `BazaWordRepository.load_pool() -> WordPool`.

- [ ] **Step 1: Write pool normalization tests**

```gdscript
func test_pool_normalizes_rejects_and_deduplicates() -> void:
    var pool := WordPool.from_entries(PackedStringArray([" кућаА ", "КУЋАА", "ABCDE", "КРАТ", "ЖИВОТ"]))
    assert_eq(pool.answers(), PackedStringArray(["КУЋАА", "ЖИВОТ"]))
    assert_true(pool.contains("кућаА"))
    assert_false(pool.contains("ABCDE"))

func test_fingerprint_is_stable_for_equal_normalized_content() -> void:
    var a := WordPool.from_entries(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
    var b := WordPool.from_entries(PackedStringArray(["живот", "авала", "ЖИВОТ"]))
    assert_eq(a.fingerprint(), b.fingerprint())
```

Run the two test files. Expected: parse failure because the classes do not exist.

- [ ] **Step 2: Implement the pure pool and file adapter**

Use `String.to_upper()`, iterate Unicode characters, require length 5 and membership in the exact alphabet constant, retain first occurrence order, and maintain a `Dictionary` as a set. Compute SHA-256 from newline-joined normalized entries:

```gdscript
class_name WordPool
extends RefCounted

const ALPHABET := "АБВГДЂЕЖЗИЈКЛЉМНЊОПРСТЋУФХЦЧЏШ"
var _answers: PackedStringArray
var _members: Dictionary

static func from_entries(entries: PackedStringArray) -> WordPool:
    var result := WordPool.new()
    result._members = {}
    for raw in entries:
        var word := raw.strip_edges().to_upper()
        if _is_valid_word(word) and not result._members.has(word):
            result._members[word] = true
            result._answers.append(word)
    return result

static func _is_valid_word(word: String) -> bool:
    if word.length() != 5:
        return false
    for letter in word:
        if not ALPHABET.contains(letter):
            return false
    return true
```

`BazaWordRepository.load_pool()` reads `res://data/baza_words.txt`, returns an empty pool on open failure, and exposes `last_error: String` for the startup fatal screen.

- [ ] **Step 3: Create a deterministic extraction tool and the real data file**

The Python tool accepts the saved reference HTML path and output path. Parse `var baza = '...'` plus every `slovo_val['token']={"print":"LETTER"...}` entry. Decode each character of the 90,325-character `baza` through that 30-entry token map, split the decoded text into five-character words, normalize, validate against the same alphabet, remove duplicates preserving order, and write one word per line. Fail on an unknown token or unless the audited invariants hold: 18,065 raw entries and 18,064 unique valid output entries. The validator independently checks UTF-8, uniqueness, alphabet, length, count, and prints a SHA-256 fingerprint for review.

Run:

```bash
python3 tools/extract_baza.py /tmp/dechko-audit.SR86rq/index.html data/baza_words.txt
python3 tools/validate_words.py data/baza_words.txt --expected-count 18064
```

Expected: `raw=18065 unique=18064 invalid=0 duplicate=1` and exit code 0. If the temporary audit file is absent, download the supplied reference URL to a new temporary directory first; do not make extraction a runtime dependency.

- [ ] **Step 4: Verify repository loading and commit**

Add a test asserting `load_pool().answers().size() == 18064`, first word `ДУПЉИ`, last word `ПАДЕЛ`, membership for both, and a 64-character fingerprint. Run the complete suite; expected: all tests pass.

```bash
git add tools/extract_baza.py tools/validate_words.py data/baza_words.txt core/domain/word_pool.gd core/infrastructure/baza_word_repository.gd tests/domain tests/infrastructure
git commit -m "feat: import and validate baza word pool"
```

### Task 3: Duplicate-aware guess evaluation

**Files:**
- Create: `core/domain/letter_mark.gd`
- Create: `core/domain/guess_row.gd`
- Create: `core/domain/guess_evaluator.gd`
- Test: `tests/domain/test_guess_evaluator.gd`

**Interfaces:**
- Produces: `LetterMark.Value { ABSENT, PRESENT, CORRECT }`; `GuessRow.new(guess: String, marks: Array[LetterMark.Value])`; `GuessEvaluator.evaluate(guess: String, answer: String) -> GuessRow`.

- [ ] **Step 1: Specify exact, present, absent, and repeated-letter behavior**

```gdscript
func test_exact_match_marks_every_letter_correct() -> void:
    assert_eq(_marks("ЖИВОТ", "ЖИВОТ"), [2, 2, 2, 2, 2])

func test_present_letters_are_consumed_only_once() -> void:
    assert_eq(_marks("ААААА", "АВАЛА"), [2, 0, 2, 0, 2])

func test_exact_pass_has_priority_over_present_pass() -> void:
    assert_eq(_marks("АБАБА", "БАБАА"), [1, 1, 1, 1, 2])
```

Run: the evaluator test. Expected: FAIL because `GuessEvaluator` is undefined.

- [ ] **Step 2: Implement the two-pass evaluator**

Validate both arguments with `WordPool._is_valid_word`. Initialize all marks to `ABSENT`; copy answer characters into an array plus a consumed boolean array. First mark and consume equal indices. Then, for every unmarked guess index, consume the first equal unconsumed answer index and mark `PRESENT`. Return an immutable-by-convention `GuessRow` exposing copies from `marks()`.

- [ ] **Step 3: Run evaluator and complete domain tests**

Add permutations covering zero matches, all-yellow anagram, two guessed duplicates against one answer occurrence, and Serbian compound letters `Љ`, `Њ`, `Џ` as single characters.

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1`

Expected: all pool and evaluator tests pass.

- [ ] **Step 4: Commit evaluation rules**

```bash
git add core/domain/letter_mark.gd core/domain/guess_row.gd core/domain/guess_evaluator.gd tests/domain/test_guess_evaluator.gd
git commit -m "feat: add duplicate-aware guess evaluation"
```

### Task 4: Board and session state machine

**Files:**
- Create: `core/domain/board_state.gd`
- Create: `core/domain/game_session.gd`
- Test: `tests/domain/test_game_session.gd`

**Interfaces:**
- Consumes: `WordPool`, `GuessEvaluator`, `GuessRow`.
- Produces: `GameSession.create(answers: PackedStringArray) -> GameSession`; `type_letter(letter: String, pool: WordPool) -> bool`; `erase_letter() -> bool`; `submit(pool: WordPool) -> bool`; getters `current_input`, `input_is_invalid`, `attempt_index`, `attempt_limit`, `status`, `boards`; status enum `ACTIVE, WON, LOST`.

- [ ] **Step 1: Write failing session behavior tests**

Test that mode sizes map to attempt limits, input stops at five letters, the fifth invalid letter sets `input_is_invalid`, erase clears it, invalid submit is rejected without consuming an attempt, valid submit mirrors one evaluated row to each unsolved board, solved boards receive no later rows, all-solved wins, and final-attempt unsolved loses.

```gdscript
func test_invalid_five_letter_guess_is_red_and_blocked() -> void:
    var session := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
    _type_word(session, "БББББ", _pool())
    assert_true(session.input_is_invalid)
    assert_false(session.submit(_pool()))
    assert_eq(session.attempt_index, 0)

func test_solved_board_freezes_while_other_board_continues() -> void:
    var session := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
    _submit(session, "ЖИВОТ", _pool())
    _submit(session, "АВАЛА", _pool())
    assert_eq(session.boards[0].rows.size(), 1)
    assert_eq(session.boards[1].rows.size(), 2)
    assert_eq(session.status, GameSession.Status.WON)
```

- [ ] **Step 2: Implement board state and input transitions**

`BoardState` owns `answer`, `rows`, `is_solved`, and `solved_attempt`; only `GameSession.submit` may append rows. `GameSession.create` rejects unsupported counts and duplicate/invalid answers. `type_letter` accepts one alphabet letter only while active and below five characters, then updates validity immediately. `submit` requires exactly five valid characters, evaluates only unsolved boards, clears input, increments the attempt once, and derives terminal state.

- [ ] **Step 3: Implement score and result idempotency fields**

Expose `score() -> int` returning `6 + boards.size() - attempt_index` only for `WON`, otherwise zero. Add `statistics_recorded: bool`; Task 6's explicit session codec must serialize and restore this field. Do not mutate it inside `score()`.

- [ ] **Step 4: Verify and commit the state machine**

Run the entire test suite. Expected: all tests pass including score boundaries 1 and 6.

```bash
git add core/domain/board_state.gd core/domain/game_session.gd tests/domain/test_game_session.gd
git commit -m "feat: implement game session state machine"
```

### Task 5: Shuffle bag, bundle creation, settings, and statistics

**Files:**
- Create: `core/application/random_port.gd`
- Create: `core/infrastructure/godot_random_source.gd`
- Create: `core/domain/answer_shuffle_bag.gd`
- Create: `core/domain/game_bundle.gd`
- Create: `core/domain/settings.gd`
- Create: `core/domain/statistics.gd`
- Create: `core/application/session_factory.gd`
- Create: `tests/doubles/fake_random_source.gd`
- Test: `tests/domain/test_answer_shuffle_bag.gd`
- Test: `tests/application/test_session_factory.gd`
- Test: `tests/domain/test_statistics.gd`

**Interfaces:**
- Consumes: `SessionFactory.new(random: RandomPort)` injects the random source used by shuffle-bag draws.
- Produces: `RandomPort.shuffle(values: Array) -> void`; `AnswerShuffleBag.draw(count: int, pool: WordPool, random: RandomPort, excluded: PackedStringArray = PackedStringArray()) -> PackedStringArray`; `SessionFactory.create_bundle(sequence: int, pool: WordPool, bag: AnswerShuffleBag) -> GameBundle`; `Statistics.record(mode: int, score: int, session_id: String) -> bool`.

- [ ] **Step 1: Write deterministic shuffle and allocation tests**

Use `FakeRandomSource` to reverse arrays. Assert 15 unique draws, no repeat until exhaustion, refill after exhaustion, and reset on fingerprint change. Assert factory allocation slices `[0]`, `[1..2]`, `[3..6]`, `[7..14]` into mode keys 1/2/4/8 and assigns limits through `GameSession`.

- [ ] **Step 2: Implement shuffle state and bundle factory**

Persist `remaining_words` and `pool_fingerprint`. On fingerprint mismatch, filter remaining words against the new pool, rebuild only if fewer than the requested count remain, and exclude every value passed through `excluded` when rebuilding. `ProgressService` passes all active-bundle answers as exclusions during pool reconciliation. `SessionFactory` calls `draw(15, pool, random)` and must fail with a typed result when fewer than 15 distinct answers are available rather than returning a partial bundle.

- [ ] **Step 3: Implement settings and idempotent statistics**

`Settings` contains theme enum `SYSTEM, DARK, LIGHT`, `reduced_motion`, and `onscreen_keyboard`. `Statistics` owns score counts 0–6 globally and per mode plus a set of recorded session IDs. Reject invalid modes/scores; return false for a duplicate session ID.

- [ ] **Step 4: Verify and commit bundle rules**

Run all tests. Expected: deterministic allocations match exactly, all 15 answers are unique, and recording the same completed session twice changes no count.

```bash
git add core/application/random_port.gd core/infrastructure/godot_random_source.gd core/domain/answer_shuffle_bag.gd core/domain/game_bundle.gd core/domain/settings.gd core/domain/statistics.gd core/application/session_factory.gd tests/doubles tests/domain tests/application
git commit -m "feat: create unlimited game bundles and statistics"
```

### Task 6: Versioned serialization and recoverable persistence

**Files:**
- Create: `core/application/save_repository_port.gd`
- Create: `core/infrastructure/user_save_repository.gd`
- Create: `core/application/progress_service.gd`
- Create: `tests/doubles/memory_save_repository.gd`
- Test: `tests/infrastructure/test_user_save_repository.gd`
- Test: `tests/application/test_progress_service.gd`

**Interfaces:**
- Produces: `SaveRepositoryPort.load_text() -> Dictionary`, `save_text(json: String) -> Error`, `preserve_corrupt(raw: String) -> Error`; `ProgressService.load_or_create() -> LoadResult`, `mark_dirty()`, `flush_now() -> Error`, `tick(delta: float) -> void`; schema version exactly `1`.

- [ ] **Step 1: Write round-trip and rejection tests**

Construct a bundle with input, submitted rows, solved state, settings, statistics, bag state, fingerprint, sequence, and `statistics_recorded`. Serialize and restore it, asserting every field. Add cases for malformed JSON, missing required keys, wrong types, unknown schema `2`, invalid active answers, and a changed fingerprint.

- [ ] **Step 2: Implement explicit codecs in `ProgressService`**

Use dictionaries containing only JSON-safe values; do not serialize Godot objects. Validate keys and types before constructing domain objects. On pool changes, retain active answers that still exist and rebuild the bag; if an active answer vanished, preserve the old file and create a fresh bundle with a warning. Record a completed restored session only when its flag is false, then immediately persist the updated flag.

- [ ] **Step 3: Implement atomic user storage and recovery**

Write `user://save_v1.json.tmp`, flush/close, rename existing save to `.previous`, rename temp to the canonical path, then remove `.previous` only after success. Corrupt/unknown saves move to `user://save_recovery_<unix_time>.json`. Return errors rather than displaying UI. In-memory state always remains usable after failure.

- [ ] **Step 4: Test debounce and immediate triggers**

With `MemorySaveRepository`, assert typing saves only after 0.35 seconds without a mutation; submission, completion, settings changes, and bundle reset call `flush_now` immediately. Assert a failed save retains dirty state and the next mutation retries.

- [ ] **Step 5: Verify and commit persistence**

Run all tests. Expected: round trip exact, invalid saves recover, debounce makes one write, and immediate mutations write synchronously.

```bash
git add core/application/save_repository_port.gd core/infrastructure/user_save_repository.gd core/application/progress_service.gd tests/doubles/memory_save_repository.gd tests/infrastructure/test_user_save_repository.gd tests/application/test_progress_service.gd
git commit -m "feat: persist and recover game progress"
```

### Task 7: Share formatting and platform adapters

**Files:**
- Create: `core/application/clipboard_port.gd`
- Create: `core/application/share_service.gd`
- Create: `core/infrastructure/godot_clipboard_adapter.gd`
- Create: `core/infrastructure/platform_capabilities.gd`
- Create: `tests/doubles/fake_clipboard.gd`
- Test: `tests/application/test_share_service.gd`
- Test: `tests/infrastructure/test_platform_capabilities.gd`

**Interfaces:**
- Produces: `ShareService.mode_text(bundle: GameBundle, mode: int) -> String`; `combined_text(bundle: GameBundle) -> String`; `copy(text: String) -> bool`; `PlatformCapabilities.is_mobile_layout(viewport_size: Vector2) -> bool`, `persistence_warning() -> String`.

- [ ] **Step 1: Write share privacy and formatting tests**

Assert the first line is exactly `УТЕРА ТИ ДЕЧКО #42`, grids use `🟩`, `🟨`, and `⬛`, mode/score are present, and neither answers nor guessed letter strings appear. Combined text must order modes 1, 2, 4, 8 and omit unfinished grids. Test successful and failed clipboard ports.

- [ ] **Step 2: Implement formatter and clipboard adapter**

Map only `LetterMark` values to emoji. Never read `BoardState.answer` when formatting. `GodotClipboardAdapter` calls `DisplayServer.clipboard_set`; on Web, verify the value when possible and return false if unavailable so the UI keeps selectable text visible.

- [ ] **Step 3: Implement capability detection**

Use `OS.get_name()`, `DisplayServer.is_touchscreen_available()`, and viewport width. Mobile layout is true for Android or a touch-capable Web viewport narrower than 720 logical pixels. Expose warnings for Web persistence/clipboard limitations without importing platform checks into domain code.

- [ ] **Step 4: Verify and commit platform services**

Run all tests. Expected: no answer leakage, clipboard fallback deterministic, desktop Web remains direct-input at wide widths.

```bash
git add core/application/clipboard_port.gd core/application/share_service.gd core/infrastructure/godot_clipboard_adapter.gd core/infrastructure/platform_capabilities.gd tests/doubles/fake_clipboard.gd tests/application/test_share_service.gd tests/infrastructure/test_platform_capabilities.gd
git commit -m "feat: add private sharing and platform capabilities"
```

### Task 8: Application coordinator and Serbian input mapping

**Files:**
- Create: `core/application/game_coordinator.gd`
- Create: `features/gameplay/input_mapper.gd`
- Test: `tests/application/test_game_coordinator.gd`
- Test: `tests/scenes/test_input_mapper.gd`

**Interfaces:**
- Consumes: `ProgressService`, `SessionFactory`, `ShareService`, `WordPool`.
- Produces: coordinator signals `state_changed`, `notice_requested(message: String)`, `confirmation_requested`; commands `type_letter`, `erase`, `submit`, `switch_mode`, `request_new_bundle`, `confirm_new_bundle`, `set_settings`; `InputMapper.map_event(event: InputEventKey) -> String`.

- [ ] **Step 1: Test complete application flows with fakes**

Cover launch with/without save, mode switch preserving input, mirrored typing delegated to the active session, invalid submission blocked, completion recorded exactly once, dirty/immediate persistence calls, unconfirmed reset with unfinished progress, confirmed whole-bundle reset, and reset without confirmation when no unfinished progress exists.

- [ ] **Step 2: Implement the coordinator as the sole mutation gateway**

Commands return early for inactive sessions, call domain methods, save according to the persistence policy, update statistics at terminal transition, and emit one `state_changed` after a successful mutation. `request_new_bundle` checks all four sessions for active progress; `confirm_new_bundle` increments the local sequence and preserves settings/statistics/bag.

- [ ] **Step 3: Encode and test input mappings**

Accept direct Cyrillic Unicode plus the reference Serbian keyboard positions:

```gdscript
const LATIN_POSITION_MAP := {
    KEY_A: "А", KEY_B: "Б", KEY_V: "В", KEY_G: "Г", KEY_D: "Д",
    KEY_BRACKETRIGHT: "Ђ", KEY_E: "Е", KEY_BACKSLASH: "Ж",
    KEY_Y: "З", KEY_Z: "З", KEY_I: "И", KEY_J: "Ј", KEY_K: "К",
    KEY_L: "Л", KEY_Q: "Љ", KEY_M: "М", KEY_N: "Н", KEY_W: "Њ",
    KEY_O: "О", KEY_P: "П", KEY_R: "Р", KEY_S: "С", KEY_T: "Т",
    KEY_APOSTROPHE: "Ћ", KEY_U: "У", KEY_F: "Ф", KEY_H: "Х",
    KEY_C: "Ц", KEY_SEMICOLON: "Ч", KEY_X: "Џ", KEY_BRACKETLEFT: "Ш",
}
```

This is the complete audited mapping; `Y` and `Z` are intentional aliases for `З`, so the dictionary has 31 key positions producing 30 distinct letters. Tests iterate this exact dictionary, assert its value set equals `WordPool.ALPHABET`, reject modifiers/unknown keys, and verify Cyrillic Unicode key events pass through uppercased.

- [ ] **Step 4: Verify and commit orchestration**

Run all tests. Expected: all coordinator mutations and all 31 physical key positions covering the 30-letter alphabet pass.

```bash
git add core/application/game_coordinator.gd features/gameplay/input_mapper.gd tests/application/test_game_coordinator.gd tests/scenes/test_input_mapper.gd
git commit -m "feat: orchestrate gameplay and physical input"
```

### Task 9: Obsidian Focus shell and home screen

**Files:**
- Create: `app/design_tokens.gd`
- Create: `app/app_theme.tres`
- Create: `app/app_theme_light.tres`
- Create: `icon.svg`
- Modify: `app/app_root.gd`
- Modify: `app/app_root.tscn`
- Create: `features/home/home_screen.gd`
- Create: `features/home/home_screen.tscn`
- Create: `features/common/notice_banner.gd`
- Create: `features/common/notice_banner.tscn`
- Test: `tests/scenes/test_app_shell.gd`
- Test: `tests/scenes/test_home_screen.gd`

**Interfaces:**
- Consumes: `GameCoordinator` state and signals.
- Produces: `HomeScreen.mode_selected(mode: int)`, `statistics_requested`, `settings_requested`, `combined_share_requested`; `AppRoot` dependency wiring and screen navigation.

- [ ] **Step 1: Write scene contract tests**

Instantiate scenes headlessly. Assert exact title and attribution copy, four mode buttons with 1/2/4/8 metadata, lower-right `НОВА ИГРА`, no removed caption strings, correct typed signals, full-rect anchors, and a notice banner that does not block input.

- [ ] **Step 2: Build design tokens and themes**

Define charcoal backgrounds/surfaces, mint success/action, gold present, red invalid/failure, off-white text, muted text, cell radius, spacing scale, and minimum 44×44 touch target. Create equivalent light tokens with WCAG-readable contrast. Centralize constants; feature scripts may not hard-code semantic colors. Create a code-native SVG app icon with a charcoal rounded square, mint five-cell row, and one gold present-position cell; omit text so it remains legible at launcher sizes.

- [ ] **Step 3: Build AppShell and HomeScreen**

Use `MarginContainer`, `VBoxContainer`, and `Control` anchors rather than position arithmetic. `AppRoot` creates repositories/services/coordinator, handles fatal empty-pool startup, connects high-level signals, and passes immutable snapshots or domain read access to screens. It owns a single screen container, frees replaced screens, and calls `ProgressService.tick(delta)` while a dirty debounce is active.

- [ ] **Step 4: Verify themes and commit shell**

Run all tests and launch the project once with `tools/run_godot.ps1 --editor`. Confirm at 1440×900: title upper-left, attribution lower-left, reset lower-right, no keyboard caption, and mode cards centered.

```bash
git add app features/home features/common tests/scenes/test_app_shell.gd tests/scenes/test_home_screen.gd
git commit -m "feat: build Obsidian Focus app shell"
```

### Task 10: Board rendering and wide-layout gameplay

**Files:**
- Create: `features/gameplay/board_view.gd`
- Create: `features/gameplay/board_view.tscn`
- Create: `features/gameplay/game_screen.gd`
- Create: `features/gameplay/game_screen.tscn`
- Test: `tests/scenes/test_board_view.gd`
- Test: `tests/scenes/test_game_screen.gd`

**Interfaces:**
- Consumes: active `GameSession` plus semantic colors from `DesignTokens`.
- Produces: `GameScreen.letter_typed(letter: String)`, `erase_requested`, `submit_requested`, `mode_selected(mode: int)`, `board_selected(index: int)`.

- [ ] **Step 1: Test board rendering states**

Assert row count equals attempt limit, five cells per row, current input mirrored only to unsolved boards, evaluated marks use the three semantic styles, invalid current rows use red border/surface, solved boards freeze, and answers are not visible before completion.

- [ ] **Step 2: Implement `BoardView.render(board, session)`**

Prebuild the fixed cell grid once, then update labels/styles without recreating nodes on each keystroke. Render submitted rows, then current input if unsolved, then empty rows. Apply invalid styling only to the active mirrored row. Add reduced-motion-aware flip/shake hooks but keep animations disabled until Task 13.

- [ ] **Step 3: Test and implement wide arrangements**

At viewport widths 1440 and 1024, assert modes 1/2 are centered, mode 4 uses four columns when minimum cell size remains 48 px, and mode 8 uses 4×2 or 8×1 only when each board meets its readable minimum. Below that threshold reduce columns and enable scrolling; never scale glyphs below the token minimum.

- [ ] **Step 4: Wire direct input without a text field**

`GameScreen._unhandled_key_input` maps keys, emits typed signals, handles Backspace and Enter, and marks handled events. There is no `LineEdit` and no permanent `KeyboardView` on Windows/wide Web. Re-render only after coordinator `state_changed`.

- [ ] **Step 5: Verify and commit desktop gameplay**

Run all tests. Manually play modes 1 and 8 on Windows: type an invalid word to see red, erase to clear red, submit a valid word, switch modes, and return to preserved progress.

```bash
git add features/gameplay/board_view.gd features/gameplay/board_view.tscn features/gameplay/game_screen.gd features/gameplay/game_screen.tscn tests/scenes/test_board_view.gd tests/scenes/test_game_screen.gd
git commit -m "feat: render responsive desktop gameplay"
```

### Task 11: Mobile focus navigator and collapsible keyboard

**Files:**
- Create: `features/gameplay/keyboard_view.gd`
- Create: `features/gameplay/keyboard_view.tscn`
- Modify: `features/gameplay/game_screen.gd`
- Modify: `features/gameplay/game_screen.tscn`
- Test: `tests/scenes/test_keyboard_view.gd`
- Test: `tests/scenes/test_mobile_game_screen.gd`

**Interfaces:**
- Produces: `KeyboardView.letter_pressed(letter: String)`, `erase_pressed`, `submit_pressed`, `collapsed_changed(collapsed: bool)`; mobile navigator state `selected_board_index` and explicit `select_board(index)`.

- [ ] **Step 1: Write keyboard and navigator tests**

Assert the keyboard contains each of the 30 Serbian letters exactly once plus erase/submit, every target is at least 44 logical pixels, collapse leaves only the reopen handle, submit collapses the sheet, and invalid guesses keep submit disabled. Assert 4/8 modes render one full board and persistent 4/8 navigator items with selected/solved/unfinished/failed states.

- [ ] **Step 2: Build the compact keyboard bottom sheet**

Use three rows matching the Serbian layout audited from the site. Buttons emit letters only; they never mutate sessions. Animate between browse and compose heights only when reduced motion is false. The optional accessibility button instantiates the same scene on desktop.

- [ ] **Step 3: Implement focus navigation and swipe**

Track touch start/end and navigate when horizontal travel exceeds 48 logical pixels and dominates vertical travel. Next/previous gestures skip solved boards while an unsolved board exists; tapping a navigator item always permits explicit solved-board review. Clamp selection after completion and orientation changes.

- [ ] **Step 4: Verify narrow portrait and landscape layouts**

Run scene tests at 390×844, 412×915, and 844×390. Expected: no clipped board cells, one readable focus board, persistent navigator, scroll only outside the board, and keyboard does not cover the current row.

- [ ] **Step 5: Commit mobile interaction**

```bash
git add features/gameplay/keyboard_view.gd features/gameplay/keyboard_view.tscn features/gameplay/game_screen.gd features/gameplay/game_screen.tscn tests/scenes/test_keyboard_view.gd tests/scenes/test_mobile_game_screen.gd
git commit -m "feat: add mobile focus navigation and keyboard"
```

### Task 12: Results, statistics, settings, and reset confirmation

**Files:**
- Create: `features/results/results_view.gd`
- Create: `features/results/results_view.tscn`
- Create: `features/results/statistics_view.gd`
- Create: `features/results/statistics_view.tscn`
- Create: `features/settings/settings_view.gd`
- Create: `features/settings/settings_view.tscn`
- Create: `features/settings/confirm_new_game_dialog.gd`
- Create: `features/settings/confirm_new_game_dialog.tscn`
- Modify: `app/app_root.gd`
- Test: `tests/scenes/test_results_view.gd`
- Test: `tests/scenes/test_statistics_view.gd`
- Test: `tests/scenes/test_settings_and_reset.gd`

**Interfaces:**
- Produces: share/copy signals, statistics mode filter, typed settings changes, reset `confirmed`/`cancelled` signals.

- [ ] **Step 1: Write result and answer-reveal tests**

Assert completion displays score 0–6, all answers with solved/missed distinction, selectable fallback share text after clipboard failure, and continuation to other modes. Assert no answer nodes exist for active sessions.

- [ ] **Step 2: Build results and statistics views**

Render seven histogram buckets (0–6) and filter chips for aggregate/1/2/4/8. Derive values from `Statistics`; views never increment counts. Copy action asks `ShareService`; show success toast or keep the selectable panel open with manual-copy guidance.

- [ ] **Step 3: Build settings and theme propagation**

Provide System/Dark/Light, reduced motion, and on-screen-keyboard preference. Emit one typed settings value object. `AppRoot` applies the theme and tells active scenes to suppress animation before immediately saving.

- [ ] **Step 4: Build reset confirmation and abandonment behavior**

The dialog states that progress in all unfinished modes will be discarded and statistics retained. Cancel mutates nothing. Confirm calls `GameCoordinator.confirm_new_bundle()` exactly once, closes results/dialog overlays, and returns HomeScreen to fresh 1/2/4/8 sessions.

- [ ] **Step 5: Verify and commit secondary flows**

Run all tests. Manually complete one mode, copy its share, inspect statistics, change theme, start progress in another mode, cancel reset, then confirm reset and verify the completed statistic remains.

```bash
git add features/results features/settings app/app_root.gd tests/scenes/test_results_view.gd tests/scenes/test_statistics_view.gd tests/scenes/test_settings_and_reset.gd
git commit -m "feat: add results statistics settings and reset"
```

### Task 13: Motion, accessibility, startup failures, and resilience UI

**Files:**
- Modify: `features/gameplay/board_view.gd`
- Modify: `features/gameplay/game_screen.gd`
- Modify: `features/common/notice_banner.gd`
- Modify: `app/app_root.gd`
- Test: `tests/scenes/test_accessibility_and_errors.gd`

**Interfaces:**
- Consumes: domain/application error results and `Settings.reduced_motion`.
- Produces: user-visible fatal startup state and non-blocking recovery/save/persistence/clipboard notices.

- [ ] **Step 1: Write failure-presentation tests**

Inject empty pool, insufficient pool, recovered corrupt save, failed save, unavailable Web persistence, and failed clipboard. Assert exact severity: pool failures replace the app with a fatal diagnostic; all other failures preserve playable state and show dismissible notices. Assert no raw stack trace or save content appears.

- [ ] **Step 2: Implement restrained state animations**

Add 120–180 ms cell reveal, invalid-row shake, and solved-board mint emphasis. Gate every tween on `not settings.reduced_motion`; with reduced motion enabled, apply final styles synchronously. Do not animate layout size during typing.

- [ ] **Step 3: Add keyboard/focus accessibility**

Set descriptive accessible names for cells (`Ред 2, слово 4, присутно`), mode buttons, navigator states, and icon-only controls. Provide visible focus styles, logical focus neighbors, Escape/back behavior, and minimum 44×44 interactive targets.

- [ ] **Step 4: Verify and commit resilience polish**

Run all tests. Launch with the word file temporarily renamed to confirm fatal startup, then restore it. Inject a malformed save and confirm it is preserved and a fresh playable bundle appears with a notice.

```bash
git add app/app_root.gd features/gameplay features/common tests/scenes/test_accessibility_and_errors.gd
git commit -m "feat: polish accessibility and recovery states"
```

### Task 14: Export presets and cross-platform release verification

**Files:**
- Create: `export_presets.cfg`
- Create: `docs/setup/godot-development.md`
- Create: `docs/testing/release-smoke-checklist.md`
- Create: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: completed application and Godot 4.7.2 export templates.
- Produces: Windows x86_64, threadless Web, and Android debug/release-ready presets under ignored `builds/`.

- [ ] **Step 1: Configure exact export presets**

Create `Windows Desktop` x86_64, `Web` with threads disabled and IndexedDB persistence enabled, and `Android` supporting portrait plus sensor-landscape rotation. Use Compatibility rendering for all. Exclude `.git`, `.superpowers`, `tests`, `tools`, `docs`, and `addons/gut` from production packs.

- [ ] **Step 2: Add development and release documentation**

Document the exact Godot path, test command, word import verification, required export templates, Android SDK/JDK settings, local HTTP requirement for Web, save locations by platform, and the manual smoke matrix. README links the approved spec, this plan, and setup guide.

- [ ] **Step 3: Run the full automated gate**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1
& 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --quit
```

Expected: zero failed GUT tests, no parser errors, no missing resources, exit code 0.

- [ ] **Step 4: Build all initial targets**

```powershell
$Godot = 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $Godot --headless --path . --export-release 'Windows Desktop' 'builds/windows/utera-ti-dechko.exe'
& $Godot --headless --path . --export-release 'Web' 'builds/web/index.html'
& $Godot --headless --path . --export-debug 'Android' 'builds/android/utera-ti-dechko-debug.apk'
```

Expected: all three commands exit 0 and the executable, Web HTML/PCK/WASM files, and APK exist.

- [ ] **Step 5: Execute the release smoke matrix**

On Windows, locally served Web in desktop and mobile responsive modes, and an Android emulator/device: launch fresh; play valid/invalid guesses; finish modes 1 and 8; switch modes; reload/restart and resume; copy share text; change theme; collapse/reopen mobile keyboard; rotate Android; create and cancel/confirm a new bundle. Verify 15 distinct answers through a debug-only state dump, then disable that dump for release.

- [ ] **Step 6: Final verification and commit**

Run `git diff --check`, the full automated suite, all three exports, and the documented smoke checklist. Record Godot version, test count, export artifact hashes, devices/browsers, and outcomes in the checklist.

```bash
git add export_presets.cfg docs/setup/godot-development.md docs/testing/release-smoke-checklist.md README.md .gitignore
git commit -m "build: configure Windows Web and Android releases"
```

## Completion gate

Before calling the implementation complete, verify every acceptance criterion from the design spec against a passing automated test or a recorded smoke-check row. Run the full test suite from a clean checkout, rebuild all three exports, confirm `git diff --check` is clean, and inspect `git status --short` so generated artifacts and local saves are not tracked.
