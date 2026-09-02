#!/usr/bin/env python3
"""Extract the encoded `baza` word list from a saved reference page."""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path


ALPHABET = "АБВГДЂЕЖЗИЈКЛЉМНЊОПРСТЋУФХЦЧЏШ"
EXPECTED_RAW_COUNT = 18_065
EXPECTED_UNIQUE_COUNT = 18_064
EXPECTED_PAYLOAD_LENGTH = EXPECTED_RAW_COUNT * 5

BAZA_PATTERN = re.compile(r"var\s+baza\s*=\s*'([^']*)'")
TOKEN_PATTERN = re.compile(
    r"slovo_val\[['\"]([^'\"]+)['\"]\]\s*=\s*\{\s*\"print\"\s*:\s*\"([^\"]+)\""
)


def is_valid_word(word: str) -> bool:
    return len(word) == 5 and all(letter in ALPHABET for letter in word)


def extract_words(html: str) -> tuple[list[str], int, int, int]:
    baza_match = BAZA_PATTERN.search(html)
    if baza_match is None:
        raise ValueError("could not find var baza assignment")
    encoded = baza_match.group(1)

    token_map = dict(TOKEN_PATTERN.findall(html))
    if len(token_map) != 30:
        raise ValueError(f"expected 30 token definitions, found {len(token_map)}")
    if len(encoded) != EXPECTED_PAYLOAD_LENGTH:
        raise ValueError(
            f"expected {EXPECTED_PAYLOAD_LENGTH} encoded tokens, found {len(encoded)}"
        )

    try:
        decoded = "".join(token_map[token] for token in encoded)
    except KeyError as error:
        raise ValueError(f"unknown token in baza payload: {error.args[0]!r}") from error

    raw_words = [decoded[index : index + 5].strip().upper() for index in range(0, len(decoded), 5)]
    invalid = sum(not is_valid_word(word) for word in raw_words)
    unique_words: list[str] = []
    seen: set[str] = set()
    duplicates = 0
    for word in raw_words:
        if not is_valid_word(word):
            continue
        if word in seen:
            duplicates += 1
            continue
        seen.add(word)
        unique_words.append(word)

    return unique_words, len(raw_words), invalid, duplicates


def fingerprint(words: list[str]) -> str:
    return hashlib.sha256("\n".join(words).encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reference_html", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    try:
        words, raw_count, invalid, duplicates = extract_words(args.reference_html.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError) as error:
        parser.error(str(error))

    if (
        raw_count != EXPECTED_RAW_COUNT
        or len(words) != EXPECTED_UNIQUE_COUNT
        or invalid != 0
        or duplicates != 1
    ):
        parser.error(
            "audited invariants failed: "
            f"raw={raw_count} unique={len(words)} invalid={invalid} duplicate={duplicates}"
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(words) + "\n", encoding="utf-8")
    print(
        f"raw={raw_count} unique={len(words)} invalid={invalid} duplicate={duplicates} "
        f"fingerprint={fingerprint(words)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
