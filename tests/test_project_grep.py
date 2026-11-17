import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'bean-grep.py'


class ProjectGrep(unittest.TestCase):
    def test_real_rg_literal_paths_ignores_columns_and_queries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "quote's $USER project"
            root.mkdir()
            (root / '.git').mkdir()
            (root / '.gitignore').write_text('ignored.txt\n')
            name = "odd:\t' $USER\nname.txt"
            line = 'αβ check_password(value)'
            (root / name).write_text('first\n' + line + '\n')
            for name2 in ['ignored.txt', 'node_modules/x.txt', '.git/private', '.cache/x']:
                path = root / name2
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('check_password\n')
            (root / '.hidden').write_text('hidden_token\n')
            env = dict(os.environ, BEAN_SEARCH_ROOT=str(root))

            def search(query):
                result = subprocess.run(['python3', str(SCRIPT), 'matches', query], env=env, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr.decode())
                return [json.loads(record.split(b'\t', 1)[0]) for record in result.stdout.split(b'\0') if record]

            records = search('check_password')
            self.assertEqual(len(records), 1)
            self.assertEqual(base64.b64decode(records[0]['path']), os.fsencode('./' + name))
            self.assertEqual(records[0]['line'], 2)
            self.assertEqual(records[0]['column'], line.encode().index(b'check_password') + 1)
            self.assertEqual(len(search('hidden_token')), 1)
            self.assertEqual(search(''), [])
            self.assertEqual(search('absent'), [])
            query = "$(touch OWNED) ' [x] $USER; & |"
            (root / 'literal.txt').write_text(query + '\n')
            self.assertEqual(len(search(query)), 1)
            self.assertFalse((root / 'OWNED').exists())
            raw = os.fsencode(root) + b'/invalid-\xff.txt'
            with open(raw, 'wb') as handle:
                handle.write(b'raw_path_token\n')
            self.assertEqual(base64.b64decode(search('raw_path_token')[0]['path']), b'./invalid-\xff.txt')


if __name__ == '__main__':
    unittest.main()
