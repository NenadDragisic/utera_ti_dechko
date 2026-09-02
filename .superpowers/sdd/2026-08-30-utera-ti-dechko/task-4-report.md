# Task 4 Report: Board and session state machine

## Implementation

- Added `BoardState`, which owns an answer, evaluated rows, solved state, and the zero-based attempt at which it was solved.
- Added `GameSession` with supported 1/2/4/8-board modes and respective 6/7/9/13 attempt limits.
- `GameSession` validates construction inputs, holds one shared input, mirrors each valid guess only to unsolved boards, freezes solved boards, derives won/lost terminal state, and exposes score and statistics-recording state.
- Added state-machine tests using the real `WordPool` and `GuessEvaluator`; no mocks are used.

## RED / GREEN evidence

- RED: after adding `tests/domain/test_game_session.gd`, the full test command reported parse errors because `GameSession` did not exist (including `Could not find type "GameSession" in the current scope`). The pre-existing suite still reported 12 passing tests.
- GREEN: after adding `BoardState` and `GameSession`, `powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/test.ps1` reported 22/22 passing tests with 216 assertions.

## Files

- `core/domain/board_state.gd`
- `core/domain/board_state.gd.uid`
- `core/domain/game_session.gd`
- `core/domain/game_session.gd.uid`
- `tests/domain/test_game_session.gd`
- `tests/domain/test_game_session.gd.uid`

## Self-review

- Confirmed mode limits, five-character input cap, invalid-word feedback and rejection, input erase recovery, one-attempt-per-valid-submit, per-board evaluation, freeze-on-solve, win/loss derivation, and score boundaries of 6 and 1.
- Confirmed invalid submission preserves the input and consumes no attempt.
- Confirmed `score()` is pure and leaves `statistics_recorded` unchanged.
- Checked the scoped change for whitespace errors with `git diff --check`.

## Concerns

- Construction validation uses GDScript `assert`, matching `GuessEvaluator`'s existing input-validation convention. A future caller that needs recoverable construction failures would require a result-style API beyond this task's typed `create(...) -> GameSession` contract.
