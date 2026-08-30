# Task 3 report: duplicate-aware guess evaluation

## Implementation

- Added `LetterMark.Value` with `ABSENT`, `PRESENT`, and `CORRECT` semantics.
- Added typed `GuessRow`, which stores a guess and returns defensive copies of its marks.
- Added pure typed `GuessEvaluator.evaluate`, validating both words with `WordPool._is_valid_word` and applying exact-before-present two-pass consumption.
- Added domain tests for exact, present, absent, duplicate, anagram, Serbian compound-letter, and defensive-copy behavior.

## Files

- `core/domain/letter_mark.gd`
- `core/domain/guess_row.gd`
- `core/domain/guess_evaluator.gd`
- `tests/domain/test_guess_evaluator.gd`

## RED

Command:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1
```

Before the production classes existed, the evaluator test failed to parse with:

```text
Parse Error: Identifier "GuessEvaluator" not declared in the current scope.
Parse Error: Identifier "LetterMark" not declared in the current scope.
```

The pre-existing pool, repository, and smoke tests still passed, confirming the failure was caused by the missing evaluator domain classes.

## GREEN and final tests

Command:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1
```

Output summary:

```text
Scripts               4
Tests                12
Passing Tests        12
Asserts              20
---- All tests passed! ----
```

The evaluator script passed 8/8 tests.

## Self-review

- Confirmed the evaluator validates both arguments before indexing and uses the shared Serbian alphabet/length contract.
- Confirmed exact matches are consumed in the first pass, then remaining guess letters consume the first matching unconsumed answer letter.
- Confirmed duplicate guesses cannot receive more positive marks than answer occurrences.
- Confirmed `String` iteration treats `Љ`, `Њ`, and `Џ` as single characters in the tested five-letter inputs.
- Confirmed `GuessRow.marks()` returns a duplicate, so callers cannot mutate stored evaluation state.
- Confirmed `git diff --check` is clean.

## Concerns

None. Invalid input is treated as a violated domain precondition via GDScript assertions, while all valid five-letter Serbian Cyrillic inputs are covered by the evaluator tests.
