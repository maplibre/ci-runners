"""Run against a built ctcache package: python test_server.py /path/to/package."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

package = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / 'static').symlink_to(package / 'share/ctcache/static')
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    base = f'http://127.0.0.1:{port}'
    key = 'test-write-key-do-not-log'
    digest = 'a' * 40
    env = dict(os.environ, CTCACHE_WEBROOT=str(root), MPLCONFIGDIR=str(root / 'matplotlib'))
    command = [str(package / 'bin/clang-tidy-cache-server'), '--port', str(port),
               '--save-path', str(root / 'index.json.gz'), '--max-cache-size', '80', '--auth-key-writes', key]
    log = open(root / 'server.log', 'w+')

    def request(path, data=None, method='GET'):
        req = urllib.request.Request(base + path, data=data, method=method)
        try:
            with urllib.request.urlopen(req, timeout=3) as response:
                return response.status, response.read()
        except urllib.error.HTTPError as error:
            return error.code, error.read()

    def start():
        process = subprocess.Popen(command, env=env, stdout=log, stderr=log)
        for _ in range(100):
            if process.poll() is not None:
                log.flush()
                raise RuntimeError((root / 'server.log').read_text())
            try:
                if request('/stats')[0] == 200:
                    return process
            except OSError:
                pass
            time.sleep(0.1)
        process.terminate()
        process.wait(timeout=30)
        raise RuntimeError('server did not become ready')

    process = start()
    try:
        payload = urllib.parse.urlencode({'data': 'cached diagnostics'}).encode()
        assert request('/cache/' + digest, payload, 'PUT')[0] == 403
        assert request('/cache/' + digest + '?key=wrong', payload, 'PUT')[0] == 403
        assert request('/cache/' + digest + '?key=' + key, payload, 'PUT')[0] == 200
        assert request('/cache/' + digest) == (200, b'cached diagnostics')
        assert request('/is_cached/' + digest) == (200, b'true')
        assert request('/purge_cache')[0] == 403
        assert request('/static/index.html')[0] == 200
        assert json.loads(request('/stats')[1])['cached_count'] == 1
    finally:
        process.terminate()
        process.wait(timeout=30)
    process = start()
    try:
        assert request('/cache/' + digest) == (200, b'cached diagnostics')
    finally:
        process.terminate()
        process.wait(timeout=30)
    log.close()
    assert key not in (root / 'server.log').read_text()
print('PASS: authenticated writes, public reads, purge rejection, dashboard, restart persistence, log redaction')
