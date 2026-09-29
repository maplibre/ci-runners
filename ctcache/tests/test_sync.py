"""Verify that host and secret synchronization have separate side effects."""
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
        self.scripts = self.root / 'ctcache/scripts'
        self.scripts.mkdir(parents=True)
        (self.root / 'infrastructure/ctcache').mkdir(parents=True)
        for name in ('sync-github-config.sh', 'sync-github-secret.sh'):
            shutil.copy(Path(__file__).parents[1] / 'scripts' / name, self.scripts / name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'calls'
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}', CALLS=str(self.log))
        self.key = 'a' * 64
        self.secret = self.root / 'auth-key'
        self.secret.write_text(self.key + '\n')
        self.mock('tofu', '[[ "$1" == "-chdir=$STACK_DIRECTORY" && "$*" == *"output -raw ctcache_host" ]]; echo "${TEST_HOST:-8.8.8.8}"')
        self.env['STACK_DIRECTORY'] = str(self.root / 'infrastructure/ctcache')
        self.mock('curl', 'test "${FAIL_HEALTH:-0}" = 0 || exit 22; echo \'{"cached_count":0}\'')
        self.mock('aws', 'echo "AWS must not be called" >&2; exit 99')
        self.mock('gh', 'echo "$*" >> "$CALLS"; if [ "$1" = secret ]; then cat > "$CALLS.stdin"; fi')

    def mock(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/env bash\nset -eu\n' + body + '\n')
        path.chmod(0o755)

    def run_script(self, name, *args, **env):
        return subprocess.run([str(self.scripts / name), *args], cwd='/',
                              env=dict(self.env, **env), capture_output=True, text=True)

    def test_host_only_updates_variable(self):
        result = self.run_script('sync-github-config.sh', '--repo', 'example/test')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            'variable set CTCACHE_HOST --repo example/test --body 8.8.8.8'])

    def test_host_failures_do_not_write_to_github(self):
        for env in ({'TEST_HOST': 'invalid'}, {'TEST_HOST': '127.0.0.1'}, {'FAIL_HEALTH': '1'}):
            with self.subTest(env=env):
                self.assertNotEqual(self.run_script('sync-github-config.sh', **env).returncode, 0)
                self.assertFalse(self.log.exists())

    def test_secret_only_updates_secret_via_stdin(self):
        self.mock('tofu', 'echo "OpenTofu must not be called" >&2; exit 99')
        self.mock('curl', 'echo "Server must not be called" >&2; exit 99')
        result = self.run_script('sync-github-secret.sh', '--repo', 'example/test', str(self.secret))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ['secret set CTCACHE_AUTH_KEY --repo example/test'])
        self.assertEqual(Path(str(self.log) + '.stdin').read_text(), self.key)
        self.assertNotIn(self.key, result.stdout + result.stderr + self.log.read_text())

    def test_bad_secret_does_not_write_to_github(self):
        for value in ('', 'invalid'):
            self.secret.write_text(value)
            self.assertNotEqual(self.run_script('sync-github-secret.sh', str(self.secret)).returncode, 0)
            self.assertFalse(self.log.exists())
        self.assertNotEqual(self.run_script('sync-github-secret.sh', str(self.root / 'missing')).returncode, 0)
        self.assertFalse(self.log.exists())

    def test_dry_runs_do_not_write_to_github(self):
        for name, args in [('sync-github-config.sh', []), ('sync-github-secret.sh', [str(self.secret)])]:
            result = self.run_script(name, '--dry-run', *args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(self.log.exists())


if __name__ == '__main__':
    unittest.main()
