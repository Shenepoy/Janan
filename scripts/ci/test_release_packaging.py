#!/usr/bin/env python3
"""Check flavor identity, entrypoint forwarding and unambiguous release names."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
FAKE_FLUTTER = '''#!/usr/bin/env python3
import json, os, pathlib, sys
args=sys.argv[1:]
flavor=args[args.index('--flavor')+1]
root=pathlib.Path.cwd()
with (root/'calls.jsonl').open('a') as f: f.write(json.dumps(args)+'\\n')
output=root/'build/app/outputs/flutter-apk';output.mkdir(parents=True,exist_ok=True)
abis=['armeabi-v7a','arm64-v8a','x86_64'] if '--split-per-abi' in args else ['']
for abi in abis:
 (output/('app-'+(abi+'-' if abi else '')+flavor+'-release.apk')).write_text(flavor)
mapping=root/'build/app/outputs/mapping'/ (flavor+'Release')/'mapping.txt'
mapping.parent.mkdir(parents=True,exist_ok=True);mapping.write_text('mapping')
symbols=pathlib.Path(next(a.split('=',1)[1] for a in args if a.startswith('--split-debug-info=')))
symbols.mkdir(parents=True,exist_ok=True)
if not os.environ.get('OMIT_TEST_SYMBOLS'):
 for arch in ['android-arm','android-arm64','android-x64']:
  (symbols/('app.'+arch+'.symbols')).write_text('symbols')
'''

class PackagingTest(unittest.TestCase):
    def check_flavor(self, production, omit_symbols=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root/'scripts/ci'
            scripts.mkdir(parents=True)
            for name in ['build_release_apk.sh', 'app_version.sh']:
                shutil.copyfile(ROOT/'scripts/ci'/name, scripts/name)
            (root/'pubspec.yaml').write_text('version: 26.11.0+84\n')
            flutter = root/'flutter'
            flutter.write_text(FAKE_FLUTTER)
            flutter.chmod(0o755)
            env = dict(os.environ, FLUTTER_BIN=str(flutter))
            for key in ['JANAN_FLAVOR','JANAN_TARGET','JANAN_DART_DEFINE_FILE','ARTIFACT_PREFIX','DIST_DIR','SYMBOLS_DIR']:
                env.pop(key, None)
            if omit_symbols: env['OMIT_TEST_SYMBOLS']='1'
            if production:
                env.update(JANAN_FLAVOR='prod', JANAN_TARGET='lib/main_cloud.dart',
                           JANAN_DART_DEFINE_FILE='/tmp/public configuration.json', ARTIFACT_PREFIX='janan')
            result=subprocess.run(['bash',str(scripts/'build_release_apk.sh')],cwd=root,env=env,
                           stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
            if omit_symbols:
                self.assertNotEqual(result.returncode,0)
                self.assertIn('Missing Dart symbols',result.stderr)
                self.assertFalse(list((root/'dist').glob('*.zip')))
                return
            self.assertEqual(result.returncode,0,result.stderr)
            prefix = 'janan' if production else 'janan-foss'
            expected = {f'{prefix}-26.11.0-{abi}.apk' for abi in ['armeabi-v7a','arm64-v8a','x86_64','universal']}
            expected.add(f'{prefix}-26.11.0-symbols.zip')
            self.assertEqual({p.name for p in (root/'dist').iterdir()},expected)
            calls=[json.loads(line) for line in (root/'calls.jsonl').read_text().splitlines()]
            self.assertEqual(len(calls),2)
            for call in calls:
                self.assertIn('--target='+('lib/main_cloud.dart' if production else 'lib/main.dart'),call)
                if production: self.assertIn('--dart-define-from-file=/tmp/public configuration.json',call)
            with zipfile.ZipFile(root/'dist'/f'{prefix}-26.11.0-symbols.zip') as archive:
                self.assertIn('r8/mapping.txt',archive.namelist())
                self.assertIn('symbols/split/app.android-arm64.symbols',archive.namelist())
                self.assertIn('symbols/universal/app.android-arm64.symbols',archive.namelist())

    def test_missing_symbols_rejected(self): self.check_flavor(False, omit_symbols=True)

    def test_foss(self): self.check_flavor(False)
    def test_production(self): self.check_flavor(True)

if __name__ == '__main__': unittest.main()
