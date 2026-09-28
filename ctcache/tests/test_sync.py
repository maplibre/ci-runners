"""Exercise failure boundaries without touching GitHub or AWS."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'scripts').mkdir()
        (self.root / 'terraform').mkdir()
        self.script = self.root / 'scripts/sync-github-config.sh'
        shutil.copy(Path(__file__).parents[1] / 'scripts/sync-github-config.sh', self.script)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'calls'
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}', CALLS=str(self.log))
        self.mock('tofu', 'case "$*" in *ctcache_host) echo "${TEST_HOST:-8.8.8.8}";; *) echo /maplibre/ctcache/auth-key;; esac')
        self.mock('curl', 'test "${FAIL_HEALTH:-0}" = 0 || exit 22; echo \'{"cached_count":0}\'')
        self.mock('aws', 'test "${FAIL_AWS:-0}" = 0 || exit 1; printf "%064d\\n" 0')
        self.mock('gh', 'echo "$*" >> "$CALLS"; if [ "$1" = secret ]; then cat >/dev/null; fi')

    def mock(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/env bash\nset -eu\n' + body + '\n')
        path.chmod(0o755)

    def run_script(self, *args, **env):
        return subprocess.run([str(self.script), *args], env=dict(self.env, **env), capture_output=True, text=True)

    def test_success(self):
        result = self.run_script('--repo', 'example/test')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            'secret set CTCACHE_AUTH_KEY --repo example/test',
            'variable set CTCACHE_HOST --repo example/test --body 8.8.8.8'])
        self.assertNotIn('0' * 64, result.stdout + result.stderr)

    def test_dry_run(self):
        self.assertEqual(self.run_script('--dry-run').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_failures_do_not_mutate_github(self):
        for env in ({'TEST_HOST': 'invalid'}, {'TEST_HOST': '127.0.0.1'}, {'FAIL_HEALTH': '1'}, {'FAIL_AWS': '1'}):
            with self.subTest(env=env):
                self.assertNotEqual(self.run_script(**env).returncode, 0)
                self.assertFalse(self.log.exists())


if __name__ == '__main__':
    unittest.main()
