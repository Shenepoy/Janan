import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('stage', Path(__file__).parents[1] / 'stage_offline_web.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StageTests(unittest.TestCase):
    def test_deterministic_complete_shell_excludes_source_and_unlisted_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            names = ['index.html', 'flutter_bootstrap.js', 'main.dart.js', 'offline.js',
                     'assets/translations/ar.json', 'canvaskit/skwasm.wasm', 'version.json',
                     '.env', 'source/private.tar.gz', 'report.json', 'main.dart.js.map']
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(name)
            module.stage(root)
            first = (root / 'janan_service_worker.js').read_text()
            module.stage(root)
            self.assertEqual(first, (root / 'janan_service_worker.js').read_text())
            manifest = json.loads(first.split('const build = ', 1)[1].split(';', 1)[0])
            self.assertEqual(set(manifest['files']), set(names[:7]))
            original = Path.read_text
            def changed_template(path, *args, **kwargs):
                text = original(path, *args, **kwargs)
                return text + '\n// Worker behavior update' if path.name == 'offline_worker.js' else text
            with patch.object(Path, 'read_text', changed_template):
                module.stage(root)
            changed = (root / 'janan_service_worker.js').read_text()
            changed_manifest = json.loads(changed.split('const build = ', 1)[1].split(';', 1)[0])
            self.assertNotEqual(manifest['version'], changed_manifest['version'])
            (root / 'main.dart.js').write_text('new build')
            module.stage(root)
            self.assertNotEqual(first, (root / 'janan_service_worker.js').read_text())
            (root / 'linked').symlink_to(root / '.env')
            with self.assertRaisesRegex(ValueError, 'Symlinks'):
                module.stage(root)

    def test_incomplete_build_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'Missing'):
                module.stage(Path(directory))


if __name__ == '__main__':
    unittest.main()
