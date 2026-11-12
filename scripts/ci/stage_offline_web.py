#!/usr/bin/env python3
"""Version only the built public shell; never discover runtime/user responses."""
import base64
import hashlib
import json
from pathlib import Path
import sys

ROOT_FILES = {
    'index.html', 'flutter_bootstrap.js', 'flutter.js', 'main.dart.js',
    'main.dart.mjs', 'main.dart.wasm', 'powersync_db.worker.js', 'sqlite3.wasm',
    'favicon.svg', 'manifest.json', 'offline.js', 'version.json',
}


def stage(directory: Path):
    directory = directory.resolve()
    for name in ['index.html', 'flutter_bootstrap.js', 'main.dart.js', 'offline.js', 'version.json']:
        if not (directory / name).is_file():
            raise ValueError(f'Missing web shell file: {name}')
    files = {}
    for path in sorted(directory.rglob('*')):
        name = path.relative_to(directory).as_posix()
        if path.is_symlink():
            raise ValueError(f'Symlinks are not allowed in the web output: {name}')
        if path.is_file() and (name in ROOT_FILES or name.startswith(('assets/', 'canvaskit/'))):
            if path.suffix in {'.map', '.deps'}:
                continue
            digest = hashlib.sha256(path.read_bytes()).digest()
            files[name] = 'sha256-' + base64.b64encode(digest).decode('ascii')
    template = Path(__file__).with_name('offline_worker.js').read_text()
    version = hashlib.sha256((json.dumps(files, sort_keys=True) + template).encode()).hexdigest()
    worker = template.replace('/* BUILD_MANIFEST */', json.dumps({'version': version, 'files': files}))
    (directory / 'janan_service_worker.js').write_text(worker)
    print(f'Offline shell: {len(files)} static files, version {version[:12]}')


if __name__ == '__main__':
    # Accept the Flutter build arguments so --output forms stay in sync.
    output = 'build/web'
    args = sys.argv[1:]
    for i, arg in enumerate(args):
        if arg.startswith('--output='):
            output = arg.split('=', 1)[1]
        elif arg in ('--output', '-o'):
            output = args[i + 1]
    stage(Path(output))
