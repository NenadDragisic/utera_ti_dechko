# Utera Ti Dechko — Godot Game Design

**Date:** 2026-08-30
**Status:** Approved design, pending written-spec review
**Targets:** Windows, Web, Android
**Engine:** Godot 4.7.2-stable, standard build, typed GDScript
**Reference:** <https://www.hangman.rs/dechko/>

## Summary

Utera Ti Dechko is an offline, unlimited Serbian Cyrillic word-guessing game based on the behavior of the reference Dechko web game. It supports 1, 2, 4, and 8 simultaneous five-letter boards. A guess is entered once and evaluated independently against every unsolved board.

The Godot version preserves the reference game's rules, scoring, word validation, duplicate-letter evaluation, progress retention, statistics, themes, and emoji sharing. It replaces the once-per-day restriction with unlimited fresh game bundles and presents the game through the approved modern “Obsidian Focus” design.

The displayed product name is **УТЕРА ТИ ДЕЧКО**. The lower-left attribution is **Ставља у погон: ПрслаФабрика**.

## Goals

- Reproduce all relevant gameplay behavior from the reference game.
- Support Windows, Web, and Android from one Godot project.
- Provide unlimited games without a server.
- Keep gameplay rules independent of scenes, controls, files, and platform APIs.
- Preserve readable boards on phones, especially in 4- and 8-word modes.
- Make the word pool replaceable without rewriting gameplay code.
- Save and resume the complete four-mode game bundle.
- Test domain and application behavior deterministically.

## Non-goals

- Daily puzzles or server-selected answers.
- Accounts, cloud synchronization, leaderboards, multiplayer, or analytics.
- Advertisements or network services.
- External Hangman.rs and Yamb.rs navigation.
- Audio in the initial release; the reference game has no gameplay audio.
- C# or native extensions.

## Reference-game audit

The served page contains the complete gameplay logic and an encoded `baza` string. The audit found:

- 90,325 encoded characters split into 18,065 five-character entries.
- 18,064 unique words; one duplicated entry will be removed during import.
- A 30-letter Serbian Cyrillic alphabet.
- Four modes: 1, 2, 4, and 8 simultaneous answers.
- Attempt limits equal to `board_count + 5`: 6, 7, 9, and 13.
- Correct duplicate-letter handling: exact-position matches consume answer letters before present-position matches.
- Input mirrored into the active row of every unsolved board.
- A five-letter input limit.
- Immediate invalid-word indication after the fifth letter.
- Submission blocked for words absent from `baza`.
- Solved boards frozen while unsolved boards continue receiving guesses.
- Scores from zero to six stars.
- Aggregate score history, per-mode results, answer reveal, and emoji sharing.
- Dark and light themes, responsive layouts, physical input, and a custom Serbian keyboard.

The reference server injects the current date, answer indexes, cookie history, and saved guesses into otherwise frontend-controlled logic. The Godot version replaces this behavior with local random selection and `user://` persistence.

## Game bundle and unlimited play

A game bundle owns four independent sessions: one for each mode. Creating a bundle draws 15 distinct answers and assigns them as follows:

| Mode | Answers | Attempts |
|---|---:|---:|
| 1 | 1 | 6 |
| 2 | 2 | 7 |
| 4 | 4 | 9 |
| 8 | 8 | 13 |

Players may switch modes at any time without losing progress. Each mode tracks its own current input, attempt index, submitted guesses, board evaluations, solved boards, result, and statistics-recorded flag.

Selecting **НОВА ИГРА** replaces all four sessions with a completely fresh bundle. If any mode contains unfinished progress, the UI asks for confirmation. Abandoned unfinished sessions are not recorded as losses. Completed results, cumulative statistics, settings, and the answer shuffle bag remain.

## Word pool and answer selection

The initial pool is the decoded `baza` from the reference page, stored as normalized UTF-8 Serbian Cyrillic with one five-letter word per line.

At load time, the repository:

1. Trims whitespace.
2. Normalizes case to uppercase.
3. Rejects entries that are not exactly five Serbian Cyrillic letters.
4. Removes duplicates.
5. Builds an ordered array for answer selection and a hash set for membership checks.

All valid pool entries may initially be used both as guesses and answers. Future pool changes occur behind the word-repository boundary.

Answer selection uses a persisted shuffle bag. It draws without replacement, ensuring the 15 answers inside a bundle are distinct and preventing repeats until the available pool is exhausted. When exhausted, the bag is rebuilt and shuffled. A changed pool fingerprint rebuilds the bag while retaining any still-valid active answers.

Randomness is injected through an interface so tests can use a deterministic source.

## Input behavior

### Shared rules

- Accept only mapped Serbian letters.
- Accept at most five letters.
- Mirror every entered or erased letter into the current row of every unsolved board.
- Do not alter solved boards.
- When the input reaches five letters, check membership immediately.
- If absent from the pool, mark all mirrored active rows red.
- Backspace removes the final letter and clears the invalid state.
- If present, keep the active rows neutral and permit submission.
- Enter submits only a valid five-letter word.
- On submission, evaluate every unsolved board, freeze newly solved boards, advance the attempt, and save progress.

Windows and desktop Web use direct physical input. They have no separate text field and no permanently visible on-screen keyboard. An accessibility button may reveal the custom keyboard.

Android and mobile Web use the same direct-to-row rules with a compact Serbian keyboard presented as a bottom sheet. The sheet can be collapsed while reviewing boards and re-opened to compose the next guess. Submitting collapses it to maximize board space.

Physical input accepts direct Cyrillic characters and reproduces the reference page's Serbian keyboard-position mappings for its 30 letters. Input mapping is centralized and tested, not embedded in scene callbacks.

## Guess evaluation

For each unsolved board:

1. Copy the five answer letters into a consumable buffer.
2. First pass: mark exact-position letters green and consume those answer positions.
3. Second pass: for each remaining guess position, find one equal unconsumed answer letter; mark it yellow and consume it.
4. Mark remaining positions absent.

This two-pass algorithm prevents repeated guess letters from receiving more positive marks than the answer contains.

## Completion and scoring

A mode succeeds when all its boards are solved. It fails when its attempt limit is reached with at least one unsolved board.

Successful score:

```text
6 + board_count - attempts_used
```

Because answers within a mode are distinct, this produces a value from one through six. Failure produces zero.

Completion:

- Freezes the session against further input.
- Reveals every answer, distinguishing solved and missed boards.
- Updates statistics exactly once, including after save/resume.
- Generates per-mode and combined share data.
- Leaves other modes in the bundle playable.

## Sharing and statistics

Per-mode sharing contains the product name, local game sequence number, and emoji evaluation grid without revealing letters or answers. The heading format is:

```text
УТЕРА ТИ ДЕЧКО #42
```

Combined sharing summarizes the 1/2/4/8 results for the current bundle. It uses the same sequence number. A deployment URL may be appended later through configuration; no URL is hard-coded in domain logic.

Statistics store score counts from zero through six and support aggregate display with optional filtering by mode. Abandoned unfinished sessions do not affect statistics.

## Visual and responsive design

The approved direction is **Obsidian Focus**:

- Dark-first charcoal surfaces.
- Mint green as the main active/success accent.
- Gold for present-position letters.
- Red for invalid input, failures, and missed answers.
- Restrained animation used only to communicate state.
- Rounded cells, controls, and panels with strong spacing and hierarchy.
- Light and system-following variants preserving contrast and meaning.

The top-left title is **УТЕРА ТИ ДЕЧКО**. The bottom-left attribution is **Ставља у погон: ПрслаФабрика**. The new-game action occupies the lower-right area. No explanatory keyboard caption is displayed in the final layout.

### Desktop and wide Web

- Show 1 and 2 modes as centered boards.
- Show 4 boards in one wide row when space permits.
- Show 8 boards in a responsive 4×2 or 8×1 arrangement depending on width.
- Fall back to fewer columns and scrolling without shrinking letters below the readable minimum.
- Physical typing fills active board rows directly.

### Android and narrow Web

- Show one full-size focus board.
- Keep a persistent 4- or 8-item navigator showing selected, solved, unfinished, and failed status.
- Permit tapping and horizontal swiping between boards.
- Automatically skip solved boards during next/previous navigation while still allowing explicit review.
- Use browse and compose states so the keyboard never permanently consumes board space.
- Support portrait and landscape layouts.

## Scenes and presentation components

Presentation uses reusable `Control` scenes:

- `AppShell`: title, theme, global navigation, responsive frame, and attribution.
- `HomeScreen`: mode selection, current results, statistics, and combined sharing.
- `GameScreen`: active session rendering, board layout, mode switching, and focus navigation.
- `BoardView`: rows, cells, evaluation colors, solved state, and invalid-input styling.
- `KeyboardView`: optional desktop keyboard and mobile bottom sheet.
- `ResultsView`: score, answers, share action, and continuation controls.
- `StatisticsView`: histogram and mode filter.
- `SettingsView`: theme, reduced motion, and on-screen-keyboard preference.
- `ConfirmNewGameDialog`: destructive bundle reset confirmation.

Scenes render provided state and emit typed signals representing player intent. They do not select words, evaluate guesses, score sessions, or access save files.

## Architecture

The project uses a layered, feature-oriented architecture.

```text
res://
├── app/                         # composition root and app-wide theme
├── core/
│   ├── domain/                 # pure RefCounted models and rules
│   ├── application/            # coordinators, use cases, and ports
│   └── infrastructure/         # repositories and platform adapters
├── features/
│   ├── gameplay/               # scenes, UI scripts, feature-local assets
│   ├── home/
│   ├── results/
│   └── settings/
├── data/                        # word pool and editable configuration Resources
└── tests/                       # mirrors core and feature boundaries
```

Godot scenes and assets are co-located by feature. Core rules remain separated because they are shared, persistent, and independently tested.

### Composition root

`AppRoot.tscn` creates infrastructure adapters, injects them into application services, creates the active coordinator, and connects high-level presentation signals. It contains no gameplay rules.

No global game-state autoload is used. An autoload is added only if a later global concern cannot be owned cleanly by `AppRoot`.

### Application layer

- `GameCoordinator`: start/resume, input, erase, submit, mode switch, and bundle reset.
- `SessionFactory`: creates four-mode bundles from selected answers.
- `ProgressService`: load, validate, migrate, debounce, and save.
- `ShareService`: format share text and delegate clipboard writes.

### Domain layer

- `GameBundle`
- `GameSession`
- `BoardState`
- `GuessRow`
- `LetterMark`
- `GuessEvaluator`
- `WordPool`
- `AnswerShuffleBag`
- `Statistics`

Domain objects use typed direct calls and return values. Signals are reserved primarily for presentation boundaries.

### Infrastructure layer

- `BazaWordRepository`
- `UserSaveRepository`
- `ClipboardAdapter`
- `PlatformCapabilities`
- `RandomSource`

Platform-dependent implementations remain behind application interfaces.

## Persistence

The versioned save is stored at `user://save_v1.json`. It contains:

- Schema version.
- Word-pool fingerprint.
- Local bundle sequence number.
- Active four-mode bundle.
- Statistics and per-mode counts.
- Settings.
- Shuffle-bag state.
- Flags preventing duplicate statistics recording.

Typing changes mark the save dirty and trigger a short debounce. Submission, completion, settings changes, and bundle replacement save immediately.

Writes go to a temporary file before replacing the previous save. Loaded JSON is validated before domain construction. Corrupt or incompatible files are preserved under a recovery filename, a fresh bundle is created, and the player receives a non-blocking notice.

## Platform configuration

- Godot 4.7.2-stable standard build.
- Typed GDScript throughout.
- Compatibility renderer.
- `canvas_items` content scaling with expanded aspect handling.
- Threadless Web export.
- Windows x86_64 initial native export.
- Android portrait and landscape support.
- No C#, GDExtension, or platform-native plugins.

Web persistence uses `user://` backed by IndexedDB. If persistence is unavailable, the game remains playable and warns that progress may be lost. Web clipboard failure leaves a selectable share panel open. Windows and Android use native clipboard behavior.

## Error handling

- Missing, empty, or unusable word data: show a fatal startup screen with a diagnostic message.
- Insufficient unique answers: block bundle creation and report the required and available counts.
- Corrupt save: preserve it, load defaults, create a new bundle, and notify the player.
- Save failure: keep the in-memory session, show a warning, and retry after the next mutation.
- Clipboard failure: retain selectable share text and provide manual-copy guidance.
- Unsupported Web persistence: show a non-blocking durability warning.
- Unknown save version: preserve the file and recover safely rather than guessing its structure.

## Testing strategy

Pin GUT 9.7.0, which includes Godot 4.7 compatibility. The addon is development-only and excluded from production exports.

### Domain tests

- Pool normalization, rejection, and deduplication.
- Membership checks.
- Five-letter input limit.
- Duplicate-letter evaluation, including repeated-letter edge cases.
- Solved-board freezing.
- Attempt limits and score boundaries.
- Bundle allocation of 1/2/4/8 answers.
- Shuffle-bag uniqueness, exhaustion, refill, and deterministic injection.
- Statistics idempotency.
- Share formatting without answer leakage.

### Application tests

- Launch with and without a save.
- Mirrored input and erasure.
- Invalid-word behavior and blocked submission.
- Mode switching and resume.
- Debounced and immediate save triggers.
- Whole-bundle replacement and abandonment semantics.
- Save migration, pool-fingerprint change, and recovery.
- Clipboard fallback through fake adapters.

### Scene tests

- Signal wiring and direct-row rendering.
- Invalid-row styling.
- Responsive desktop board arrangements.
- Mobile focus navigator and swipe behavior.
- Adaptive keyboard browse/compose states.
- Results, statistics, themes, reduced motion, and confirmation dialog.

Tests run headlessly. Release verification also includes real Windows, locally served Web, and Android emulator/device smoke tests.

## Acceptance criteria

The initial release is complete when:

1. All four modes implement the audited rules and attempt limits.
2. A fresh bundle always contains 15 distinct answers.
3. Input is capped at five letters and mirrored across unsolved boards.
4. Invalid words turn active rows red and cannot be submitted.
5. Duplicate-letter evaluation matches the two-pass reference behavior.
6. Mode switching, application restart, and browser reload preserve progress where the platform permits persistence.
7. New game replaces all four modes while retaining statistics and settings.
8. Windows, Web, and Android layouts match the approved Obsidian Focus direction.
9. Mobile 4/8 modes use a readable focus board and persistent navigator.
10. Sharing does not reveal answers and has a manual Web fallback.
11. Automated tests pass headlessly.
12. Windows, Web, and Android exports launch and complete a smoke-test game.

## Primary references

- Godot release archive: <https://godotengine.org/download/archive/>
- Godot project organization: <https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html>
- Godot scene organization: <https://docs.godotengine.org/en/latest/tutorials/best_practices/scene_organization.html>
- Godot node alternatives: <https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html>
- Godot Resources: <https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html>
- Godot signals: <https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html>
- Godot multiple resolutions: <https://docs.godotengine.org/en/latest/tutorials/rendering/multiple_resolutions.html>
- Godot Web export limitations: <https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html>
- Godot Android export: <https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html>
- GUT 9.7.0: <https://github.com/bitwes/Gut/releases/tag/v9.7.0>
