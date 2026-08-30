#!/usr/bin/env python3
"""Independently validate an extracted `baza` word list."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


ALPHABET = "АБВГДЂЕЖЗИЈКЛЉМНЊОПРСТЋУФХЦЧЏШ"


def is_valid_word(word: str) -> bool:
    return len(word) == 5 and all(letter in ALPHABET for letter in word)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("word_file", type=Path)
    parser.add_argument("--expected-count", type=int)
    args = parser.parse_args()

    try:
        words = args.word_file.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as error:
        parser.error(str(error))

    invalid = [word for word in words if not is_valid_word(word)]
    duplicates = len(words) - len(set(words))
    fingerprint = hashlib.sha256("\n".join(words).encode("utf-8")).hexdigest()
    print(
        f"count={len(words)} invalid={len(invalid)} duplicate={duplicates} "
        f"fingerprint={fingerprint}"
    )

    errors: list[str] = []
    if args.expected_count is not None and len(words) != args.expected_count:
        errors.append(f"expected {args.expected_count} words, found {len(words)}")
    if invalid:
        errors.append(f"found {len(invalid)} invalid words")
    if duplicates:
        errors.append(f"found {duplicates} duplicate words")
    if errors:
        parser.error("; ".join(errors))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
