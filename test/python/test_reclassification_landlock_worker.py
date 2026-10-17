"""Fail-closed contract tests; never restrict the test process itself."""
import ctypes
import errno
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'script'))
import video_asset_reclassification_landlock as sandbox
import video_asset_reclassification_worker as worker


class LandlockWorkerTest(unittest.TestCase):
    def test_uapi_structures_and_mask(self):
        self.assertEqual(8, ctypes.sizeof(sandbox.Ruleset))
        self.assertEqual(12, ctypes.sizeof(sandbox.PathRule))
        self.assertEqual(32754, sandbox.WRITE_ACCESS)

    def test_unknown_architecture_is_refused(self):
        with mock.patch.object(sandbox.platform, 'machine', return_value='unknown'), mock.patch.object(sandbox.ctypes, 'CDLL') as libc:
            with self.assertRaises(RuntimeError):
                sandbox.restrict_writes((1, 2, 3))
            libc.assert_not_called()

    def test_old_abi_and_unavailable_syscalls_are_refused(self):
        for result, exception in ((2, RuntimeError), (-1, OSError)):
            library = mock.Mock()
            library.syscall.return_value = result
            with mock.patch.object(sandbox.platform, 'machine', return_value='x86_64'), mock.patch.object(sandbox.ctypes, 'CDLL', return_value=library):
                with self.assertRaises(exception):
                    sandbox.restrict_writes((1, 2, 3))
                library.prctl.assert_not_called()

    def test_ruleset_is_closed_when_rule_installation_fails(self):
        library = mock.Mock()
        library.syscall.side_effect = [3, 1234, -1]
        with mock.patch.object(sandbox.platform, 'machine', return_value='x86_64'), mock.patch.object(sandbox.ctypes, 'CDLL', return_value=library), mock.patch.object(sandbox.os, 'close') as close:
            with self.assertRaises(OSError):
                sandbox.restrict_writes((1, 2, 3))
            close.assert_called_once_with(1234)
            library.prctl.assert_not_called()

    def test_success_requires_three_rules_and_restrict_self(self):
        library = mock.Mock()
        library.syscall.side_effect = [3, 1234, 0, 0, 0, 0]
        library.prctl.return_value = 0
        with mock.patch.object(sandbox.platform, 'machine', return_value='x86_64'), mock.patch.object(sandbox.ctypes, 'CDLL', return_value=library), mock.patch.object(sandbox.os, 'close') as close:
            self.assertEqual(3, sandbox.restrict_writes((1, 2, 3)))
            self.assertEqual([444, 444, 445, 445, 445, 446], [call.args[0].value for call in library.syscall.call_args_list])
            library.prctl.assert_called_once()
            close.assert_called_once_with(1234)

    def test_production_loader_always_enables_policy(self):
        backend = mock.Mock()
        with mock.patch.object(worker.base, 'load_worker', return_value=backend):
            self.assertIs(backend, worker.load_worker(Path('/run/private/plan.json'), Path('/run/private/worker.sock')))
            self.assertEqual(Path('/run/private'), backend.sandbox_runtime)

    def test_policy_failure_prevents_probe_and_rename(self):
        with tempfile.TemporaryDirectory(dir='/tmp') as directory:
            root = Path(directory)
            for name in ('source', 'target', 'runtime'):
                (root / name).mkdir()
            source, target = root / 'source/a.mkv', root / 'target/b.mkv'
            source.write_bytes(b'fixture')
            identity = worker.base.identity(source.stat())
            backend = worker.CrossDirectoryRename(source, target, identity)
            backend.sandbox_runtime = root / 'runtime'
            backend.native = mock.Mock()
            with mock.patch.object(worker, 'restrict_writes', side_effect=OSError(errno.ENOSYS, 'Unavailable')):
                with self.assertRaises(OSError):
                    backend.execute(dict(op='probe', source=str(source), target=str(target), identity=identity))
            self.assertEqual(b'fixture', source.read_bytes())
            self.assertFalse(target.exists())
            backend.native.assert_not_called()
