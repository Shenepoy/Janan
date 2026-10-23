#!/usr/bin/env python3
"""Exercise Java's actual Properties loader using synthetic credentials only."""
import os
from pathlib import Path
import subprocess
import tempfile

from write_signing_properties import write_properties


def main() -> None:
    values = {
        "storeFile": "C:\\synthetic path\\key.jks",
        "storePassword": " leading space\\backslash\nnewline\ttab=:# !",
        "keyAlias": "اسم تجريبي 🩺",
        "keyPassword": "different\rpassword\fend\\",
    }
    with tempfile.TemporaryDirectory(prefix="janan_signing_properties_") as directory:
        path = Path(directory) / "key.properties"
        write_properties(path, values)
        if path.stat().st_mode & 0o077:
            raise AssertionError("Signing properties are accessible to other users")
        environment = {**os.environ, **{f"TEST_{key}": value for key, value in values.items()}}
        subprocess.run(["java", str(Path(__file__).with_name("SigningPropertiesProbe.java")), str(path)],
                       env=environment, check=True)


if __name__ == "__main__":
    main()
