"""Only /tmp fixtures are renamed; manifest-path tests never access /videos."""
import ctypes
import errno
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import types
import unittest
from unittest import mock

WORKER_PATH = Path(__file__).resolve().parents[2] / 'script/video_asset_rename_worker.py'
spec = importlib.util.spec_from_file_location('vidb_rename_worker', WORKER_PATH)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class RelocationWorkerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='vidb-worker-', dir='/tmp')
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.source = self.directory / 'old.mkv'
        self.target = self.directory / 'new.mkv'
        self.source.write_bytes(b'fixture')
        self.expected = worker.identity(self.source.stat())
        self.backend = worker.FixedRename(str(self.source), str(self.target), self.expected)

    def request(self, op='rename'):
        return dict(op=op, source=str(self.source), target=str(self.target), identity=self.expected)

    def manifest(self):
        return dict(format='vidb.relocation_request', version=1, execution_authorized=True, root='/videos',
                    record_id=1, asset_id=2, source='/videos/Films/Science fiction/old.mkv',
                    target='/videos/Films/Science fiction/new.mkv', identity=self.expected)

    def test_rename_preserves_inode_and_content(self):
        self.assertEqual(self.backend.execute(self.request()), {'status': 'renamed'})
        self.assertFalse(self.source.exists())
        self.assertEqual(self.target.stat().st_ino, self.expected['ino'])
        self.assertEqual(self.target.read_bytes(), b'fixture')

    def test_probe_does_not_write(self):
        self.assertEqual(self.backend.execute(self.request('probe')), {'status': 'ready'})
        self.assertEqual(worker.identity(self.source.stat()), self.expected)
        self.assertFalse(self.target.exists())

    def test_occupied_destination_and_dangling_symlink_are_refused(self):
        self.target.write_bytes(b'keep')
        with self.assertRaises(FileExistsError):
            self.backend.execute(self.request())
        self.assertEqual(self.target.read_bytes(), b'keep')
        self.target.unlink()
        self.target.symlink_to(self.directory / 'missing')
        with self.assertRaises(FileExistsError):
            self.backend.execute(self.request())
        self.assertTrue(self.source.exists())

    def test_same_size_modification_is_refused(self):
        self.source.write_bytes(b'changed')
        old = self.expected['mtime_ns'] - 1_000_000_000
        os.utime(self.source, ns=(old, old))
        with self.assertRaises(ValueError):
            self.backend.execute(self.request())
        self.assertTrue(self.source.exists())

    def test_source_and_ancestor_symlinks_are_refused(self):
        link = self.directory / 'link'
        link.symlink_to(self.directory, target_is_directory=True)
        backend = worker.FixedRename(link / 'old.mkv', link / 'new.mkv', self.expected)
        with self.assertRaises(OSError):
            backend.execute(dict(op='rename', source=str(link / 'old.mkv'), target=str(link / 'new.mkv'),
                                 identity=self.expected))
        self.source.unlink()
        self.source.symlink_to(self.directory / 'missing')
        with self.assertRaises(OSError):
            self.backend.execute(self.request())

    def test_changed_request_scope_is_refused(self):
        for key, value in [('source', '/etc/passwd'), ('target', '/etc/passwd'), ('identity', {}), ('op', 'exec')]:
            request = self.request()
            request[key] = value
            with self.assertRaises(ValueError):
                self.backend.execute(request)
        self.assertTrue(self.source.exists())

    def test_destination_created_at_the_native_call_is_never_overwritten(self):
        native = self.backend.native
        def race(*args):
            self.target.write_bytes(b'keep')
            return native(*args)
        self.backend.native = race
        with self.assertRaises(FileExistsError):
            self.backend.execute(self.request())
        self.assertEqual(self.target.read_bytes(), b'keep')
        self.assertTrue(self.source.exists())

    def test_native_failure_has_no_fallback(self):
        def denied(*_args):
            ctypes.set_errno(errno.EACCES)
            return -1
        self.backend.native = denied
        with self.assertRaises(PermissionError):
            self.backend.execute(self.request())
        self.assertTrue(self.source.exists())
        self.assertFalse(self.target.exists())

    def test_manifest_is_generic_but_same_directory_and_root_scoped(self):
        backend = worker.worker_from_request(self.manifest())
        self.assertEqual(str(backend.source), '/videos/Films/Science fiction/old.mkv')
        self.assertEqual(backend.expected, self.expected)
        # The manifest constructor reads no video file.
        self.assertTrue(self.source.exists())

    def test_invalid_manifest_scope_and_authorization_are_refused(self):
        cases = [('execution_authorized', False), ('execution_authorized', 1), ('version', True),
                 ('record_id', 0), ('asset_id', True), ('root', '/tmp'),
                 ('source', '/etc/passwd'), ('target', '/videos/Films/Other/new.mkv'),
                 ('target', '/videos/Films/Science fiction/../new.mkv'),
                 ('target', '/videos/Films/Science fiction/new\n.mkv'), ('identity', {})]
        for key, value in cases:
            document = self.manifest()
            document[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                worker.worker_from_request(document)

    def test_manifest_file_is_private_and_root_owned(self):
        path = self.directory / 'plan.json'
        path.write_text(json.dumps(self.manifest()))
        path.chmod(0o600)
        real_fstat = os.fstat
        def root_info(fd):
            info = real_fstat(fd)
            return types.SimpleNamespace(st_mode=info.st_mode, st_uid=0)
        with mock.patch.object(worker.os, 'fstat', side_effect=root_info):
            self.assertEqual(worker.load_worker(path, self.directory / 'worker.sock').expected, self.expected)
            path.chmod(0o640)
            with self.assertRaises(ValueError):
                worker.load_worker(path, self.directory / 'worker.sock')
        path.chmod(0o600)
        with mock.patch.object(worker.os, 'fstat', return_value=types.SimpleNamespace(st_mode=0o100600, st_uid=1000)):
            with self.assertRaises(ValueError):
                worker.load_worker(path, self.directory / 'worker.sock')

    def test_manifest_symlink_and_oversize_are_refused(self):
        path = self.directory / 'plan.json'
        path.symlink_to(self.source)
        with self.assertRaises(OSError):
            worker.load_worker(path, self.directory / 'worker.sock')
        path.unlink()
        path.write_bytes(b'x' * 16385)
        path.chmod(0o600)
        with mock.patch.object(worker.os, 'fstat', return_value=types.SimpleNamespace(st_mode=0o100600, st_uid=0)):
            with self.assertRaises(ValueError):
                worker.load_worker(path, self.directory / 'worker.sock')


if __name__ == '__main__':
    unittest.main()
