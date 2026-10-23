#!/usr/bin/env python3
"""Serialize signing credentials in Java Properties' byte-oriented format."""
import os
from pathlib import Path
import sys


def escape_value(value: str) -> str:
    """Escape UTF-16 code units, including whitespace and non-ASCII passwords."""
    encoded = value.encode("utf-16-be")
    result = []
    escapes = {9: r"\t", 10: r"\n", 12: r"\f", 13: r"\r"}
    for offset in range(0, len(encoded), 2):
        code = int.from_bytes(encoded[offset:offset + 2], "big")
        if code in escapes:
            result.append(escapes[code])
        elif code < 32 or code > 126:
            result.append(f"\\u{code:04x}")
        else:
            char = chr(code)
            result.append("\\" + char if char in "\\ =:#!" else char)
    return "".join(result)


def write_properties(path: Path, values: dict[str, str]) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, "w", encoding="ascii", newline="\n") as handle:
        for key, value in values.items():
            handle.write(f"{key}={escape_value(value)}\n")


if __name__ == "__main__":
    write_properties(Path(sys.argv[2]), {
        "storeFile": sys.argv[1],
        "storePassword": os.environ["KEYSTORE_PASSWORD"],
        "keyAlias": os.environ["KEY_ALIAS"],
        "keyPassword": os.environ.get("KEY_PASSWORD") or os.environ["KEYSTORE_PASSWORD"],
    })
