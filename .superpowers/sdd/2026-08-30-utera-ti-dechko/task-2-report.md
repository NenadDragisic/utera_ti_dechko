# Task 2 report: audited `baza` word pool

## Implementation

- Added `WordPool`, a typed pure domain value that trims, uppercases, validates five-letter Serbian Cyrillic entries, preserves first occurrence order, supports membership checks, and hashes normalized newline-joined content with SHA-256.
- Added `BazaWordRepository`, which loads `res://data/baza_words.txt`, produces an empty pool and records `last_error` if opening fails.
- Added deterministic extraction and independent validation tools. Extraction parses the encoded `var baza` assignment and all 30 `slovo_val` token definitions before decoding; it does not interpret the encoded payload as words.
- Added the extracted 18,064-word UTF-8 data file and enabled recursive GUT discovery in the PowerShell runner so the domain and infrastructure tests are part of the full suite.

## Files

- `core/domain/word_pool.gd`
- `core/infrastructure/baza_word_repository.gd`
- `data/baza_words.txt`
- `tools/extract_baza.py`
- `tools/validate_words.py`
- `tools/test.ps1`
- `tests/domain/test_word_pool.gd`
- `tests/infrastructure/test_baza_word_repository.gd`

## RED

Command:

```text
'/mnt/c/Users/Nenad/Desktop/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/domain/test_word_pool.gd,res://tests/infrastructure/test_baza_word_repository.gd -gexit
```

Relevant output before production classes existed:

```text
Parse Error: Identifier "WordPool" not declared in the current scope.
Parse Error: Identifier "BazaWordRepository" not declared in the current scope.
[GUT ERROR]: Nothing was run.
```

After implementing the pure pool and adapter but before generating the data file, the domain tests passed and the repository integration test failed with an empty pool (`expected to equal [18064]`), demonstrating the remaining missing data dependency.

## GREEN and audited data

Commands:

```text
python3 tools/extract_baza.py /tmp/dechko-audit.SR86rq/index.html data/baza_words.txt
python3 tools/validate_words.py data/baza_words.txt --expected-count 18064
```

Output:

```text
raw=18065 unique=18064 invalid=0 duplicate=1 fingerprint=0152ee75650f9fd2568ca4ad6c4c93db5eb3d01758d0ec30fe158063847b7fed
count=18064 invalid=0 duplicate=0 fingerprint=0152ee75650f9fd2568ca4ad6c4c93db5eb3d01758d0ec30fe158063847b7fed
```

The generated file has 18,064 lines. Its first word is `ДУПЉИ`; its last word is `ПАДЕЛ`.

## Final tests

Command:

```text
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/test.ps1
```

Output summary:

```text
Scripts               3
Tests                 4
Passing Tests         4
Asserts              11
---- All tests passed! ----
```

## Self-review

- Confirmed extraction decodes every single payload token through exactly 30 parsed definitions, rejects unknown tokens, and enforces the audited raw/unique/invalid/duplicate totals.
- Confirmed validator independently checks UTF-8 decoding, count, uniqueness, length, exact alphabet membership, and reports SHA-256 over newline-joined entries.
- Confirmed `WordPool` uses the same exact alphabet and normalization rules as the extraction tool, retains insertion order, and hashes the same canonical content form.
- Confirmed the repository test asserts the audited count, first/last values, membership, and fingerprint length through the real resource file.
- Confirmed the test runner now recurses into the prescribed `tests/domain` and `tests/infrastructure` locations.

## Concerns

None. The source audit HTML is deliberately used only by the development extraction tool; runtime loading uses the checked-in UTF-8 word list.
