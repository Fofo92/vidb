"""Cross-directory fixtures stay under /tmp; manifest validation never opens /videos."""
import ctypes
import errno
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'script'))
import video_asset_reclassification_worker as worker


class ReclassificationWorkerTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vidb-reclassify-', dir='/tmp')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.first, self.second = self.root / 'first', self.root / 'second'
        self.first.mkdir()
        self.second.mkdir()
        self.source, self.target = self.first / 'old.mkv', self.second / 'new.mkv'
        self.source.write_bytes(b'fixture')
        self.expected = worker.base.identity(self.source.stat())
        self.backend = worker.CrossDirectoryRename(self.source, self.target, self.expected)

    def request(self, op='rename'):
        return dict(op=op, source=str(self.source), target=str(self.target), identity=self.expected)

    def manifest(self):
        return dict(format='vidb.reclassification_request', version=1, execution_authorized=True,
                    root='/videos', record_id=1, asset_id=2, category='film',
                    source='/videos/Films/Drame/old.mkv', target='/videos/Films/Espionnage/new.mkv',
                    identity=self.expected)

    def test_cross_directory_rename_preserves_inode_contents_and_mtime(self):
        self.assertEqual({'status': 'renamed'}, self.backend.execute(self.request()))
        self.assertFalse(self.source.exists())
        self.assertEqual(b'fixture', self.target.read_bytes())
        self.assertEqual(self.expected['ino'], self.target.stat().st_ino)
        self.assertEqual(self.expected['mtime_ns'], self.target.stat().st_mtime_ns)

    def test_probe_changes_neither_source_nor_destination(self):
        self.assertEqual({'status': 'ready'}, self.backend.execute(self.request('probe')))
        self.assertEqual(self.expected, worker.base.identity(self.source.stat()))
        self.assertFalse(self.target.exists())

    def test_existing_destination_and_dangling_symlink_are_refused(self):
        self.target.write_bytes(b'keep')
        with self.assertRaises(FileExistsError):
            self.backend.execute(self.request())
        self.assertEqual(b'keep', self.target.read_bytes())
        self.target.unlink()
        self.target.symlink_to(self.second / 'missing')
        with self.assertRaises(FileExistsError):
            self.backend.execute(self.request())
        self.assertTrue(self.source.exists())

    def test_last_instant_destination_is_never_overwritten(self):
        native = self.backend.native
        def race(*args):
            self.target.write_bytes(b'keep')
            return native(*args)
        self.backend.native = race
        with self.assertRaises(FileExistsError):
            self.backend.execute(self.request())
        self.assertEqual(b'keep', self.target.read_bytes())
        self.assertTrue(self.source.exists())

    def test_missing_directory_is_not_created(self):
        self.second.rmdir()
        with self.assertRaises(FileNotFoundError):
            self.backend.execute(self.request())
        self.assertFalse(self.second.exists())
        self.assertTrue(self.source.exists())

    def test_symlink_target_parent_is_refused(self):
        self.second.rmdir()
        self.second.symlink_to(self.first, target_is_directory=True)
        with self.assertRaises(OSError):
            self.backend.execute(self.request())
        self.assertTrue(self.source.exists())

    def test_source_symlink_is_refused(self):
        self.source.unlink()
        self.source.symlink_to(self.first / 'missing')
        with self.assertRaises(OSError):
            self.backend.execute(self.request())
        self.assertFalse(self.target.exists())

    def test_same_size_modification_is_refused(self):
        self.source.write_bytes(b'changed')
        old = self.expected['mtime_ns'] - 1_000_000_000
        os.utime(self.source, ns=(old, old))
        with self.assertRaises(ValueError):
            self.backend.execute(self.request())
        self.assertTrue(self.source.exists())

    def test_json_dependency_on_either_side_is_refused(self):
        for path in (self.source.with_suffix('.json'), self.target.with_suffix('.JSON')):
            with self.subTest(path=path):
                path.write_text('{}')
                with self.assertRaises(ValueError):
                    self.backend.execute(self.request())
                path.unlink()
        self.assertTrue(self.source.exists())

    def test_different_device_is_refused_before_native_rename(self):
        real_stat = os.fstat
        def device(fd):
            if os.readlink('/proc/self/fd/' + str(fd)) == str(self.second):
                return types.SimpleNamespace(st_dev=self.expected['dev'] + 1)
            return real_stat(fd)
        with mock.patch.object(worker.os, 'fstat', side_effect=device):
            with self.assertRaises(ValueError):
                self.backend.execute(self.request())
        self.assertTrue(self.source.exists())

    def test_native_exdev_has_no_copy_fallback(self):
        def denied(*_args):
            ctypes.set_errno(errno.EXDEV)
            return -1
        self.backend.native = denied
        with self.assertRaises(OSError) as error:
            self.backend.execute(self.request())
        self.assertEqual(errno.EXDEV, error.exception.errno)
        self.assertTrue(self.source.exists())
        self.assertFalse(self.target.exists())

    def test_both_parent_directories_are_synced(self):
        parents = []
        real_sync = os.fsync
        def sync(fd):
            parents.append(os.fstat(fd).st_ino)
            real_sync(fd)
        with mock.patch.object(worker.os, 'fsync', side_effect=sync):
            self.backend.execute(self.request())
        self.assertEqual([self.first.stat().st_ino, self.second.stat().st_ino], parents)

    def test_post_rename_error_is_reported_without_automatic_inverse_move(self):
        with mock.patch.object(self.backend, 'verify_target', side_effect=ValueError('fixture')):
            with self.assertRaises(ValueError):
                self.backend.execute(self.request())
        self.assertEqual('after_rename', self.backend.phase)
        self.assertFalse(self.source.exists())
        self.assertTrue(self.target.exists())

    def test_request_cannot_change_fixed_scope(self):
        for key, value in [('source', '/etc/passwd'), ('target', '/etc/passwd'), ('identity', {}), ('op', 'exec')]:
            request = self.request()
            request[key] = value
            with self.assertRaises(ValueError):
                self.backend.execute(request)

    def test_manifest_accepts_film_and_documentary_targets(self):
        self.assertIsInstance(worker.worker_from_request(self.manifest()), worker.CrossDirectoryRename)
        manifest = self.manifest()
        manifest.update(category='documentary', target='/videos/Documentaires/new.mkv')
        self.assertEqual(Path('/videos/Documentaires/new.mkv'), worker.worker_from_request(manifest).target)

    def test_private_manifest_loader_uses_the_reclassification_factory(self):
        manifest = self.root / 'plan.json'
        manifest.write_text(json.dumps(self.manifest()))
        manifest.chmod(0o600)
        real_stat = os.fstat
        def owned(fd):
            info = real_stat(fd)
            return types.SimpleNamespace(st_mode=info.st_mode, st_uid=0)
        with mock.patch.object(worker.base.os, 'fstat', side_effect=owned):
            backend = worker.load_worker(manifest, self.root / 'worker.sock')
        self.assertIsInstance(backend, worker.CrossDirectoryRename)

    def test_manifest_rejects_wrong_root_category_scope_and_authorization(self):
        cases = [('format', 'vidb.relocation_request'), ('version', True), ('execution_authorized', 1),
                 ('root', '/tmp'), ('record_id', 0), ('asset_id', True), ('category', 'series'),
                 ('source', '/videos/Documentaires/old.mkv'), ('source', '/videos/Films/a/b/old.mkv'),
                 ('target', '/videos/Films/Drame/new.mkv'), ('target', '/videos/Documentaires/new.mkv'),
                 ('target', '/videos/Films/../new.mkv'), ('target', '/videos/Films/Test/new\n.mkv'),
                 ('target', '/videos/Films/Test/new.mp4'), ('identity', {})]
        for key, value in cases:
            manifest = self.manifest()
            manifest[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                worker.worker_from_request(manifest)


if __name__ == '__main__':
    unittest.main()
