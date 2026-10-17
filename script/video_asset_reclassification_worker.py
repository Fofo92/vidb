#!/usr/bin/env python3
"""One manifest-pinned rename between existing directories on the same device."""
import ctypes
import errno
import os
from pathlib import Path
import stat
import sys
import json

import video_asset_rename_worker as base
from video_asset_reclassification_landlock import restrict_writes


class CrossDirectoryRename(base.FixedRename):
    def __init__(self, source, target, expected):
        for path in (source, target):
            if os.path.normpath(os.fspath(path)) != os.fspath(path):
                raise ValueError('Canonical paths required')
        super().__init__(source, target, expected)
        self.sandbox_runtime = None
        self.sandboxed = False

    @staticmethod
    def open_directory(path):
        flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_DIRECTORY
        fd = os.open('/', flags)
        try:
            for part in path.parts[1:]:
                child = os.open(part, flags, dir_fd=fd)
                os.close(fd)
                fd = child
            return fd
        except BaseException:
            os.close(fd)
            raise

    def open_parents(self):
        if not self.source.is_absolute() or not self.target.is_absolute() or self.source.parent == self.target.parent:
            raise ValueError('Two distinct absolute directories required')
        source_parent = self.open_directory(self.source.parent)
        try:
            target_parent = self.open_directory(self.target.parent)
            return source_parent, target_parent
        except BaseException:
            os.close(source_parent)
            raise

    def check_parents(self, source_parent, target_parent):
        for fd in (source_parent, target_parent):
            if os.fstat(fd).st_dev != self.expected['dev']:
                raise ValueError('Directories and source must use the pinned device')
            if os.fstatvfs(fd).f_flag & os.ST_RDONLY:
                raise ValueError('Read-only filesystem')
        for fd, path in ((source_parent, self.source), (target_parent, self.target)):
            if any(name.lower().endswith('.json') and name.startswith(path.stem) for name in os.listdir(fd)):
                raise ValueError('Adjacent JSON dependency')

    def execute(self, request):
        self.validate_request(request)
        source_parent, target_parent = self.open_parents()
        source = None
        try:
            if self.sandbox_runtime is not None and not self.sandboxed:
                runtime = self.open_directory(self.sandbox_runtime)
                try:
                    restrict_writes((source_parent, target_parent, runtime))
                    self.sandboxed = True
                finally:
                    os.close(runtime)
            self.check_parents(source_parent, target_parent)
            source = self.checked_source(source_parent)
            try:
                os.stat(self.target.name, dir_fd=target_parent, follow_symlinks=False)
            except FileNotFoundError:
                pass
            else:
                raise FileExistsError(errno.EEXIST, 'Destination occupied')
            if request['op'] == 'probe':
                return {'status': 'ready'}
            result = self.native(source_parent, os.fsencode(self.source.name),
                                 target_parent, os.fsencode(self.target.name), 1)
            if result != 0:
                code = ctypes.get_errno()
                raise OSError(code, os.strerror(code))
            self.phase = 'after_rename'
            os.fsync(source_parent)
            os.fsync(target_parent)
            self.verify_target(target_parent)
            return {'status': 'renamed'}
        finally:
            if source is not None:
                os.close(source)
            os.close(source_parent)
            os.close(target_parent)

    def verify_target(self, target_parent):
        expected = {key: value for key, value in self.expected.items() if key != 'ctime_ns'}
        for info in (os.stat(self.target.name, dir_fd=target_parent, follow_symlinks=False), os.lstat(self.target)):
            actual = {key: value for key, value in base.identity(info).items() if key != 'ctime_ns'}
            if not stat.S_ISREG(info.st_mode) or actual != expected:
                raise ValueError('Target identity changed after rename')
        if os.path.lexists(self.source):
            raise ValueError('Source path reappeared after rename')


def worker_from_request(document):
    if not isinstance(document, dict) or document.get('format') != 'vidb.reclassification_request' or \
            type(document.get('version')) is not int or document['version'] != 1 or \
            document.get('execution_authorized') is not True or document.get('root') != '/videos':
        raise ValueError('Explicitly authorized reclassification manifest required')
    for key in ('record_id', 'asset_id'):
        if type(document.get(key)) is not int or document[key] <= 0:
            raise ValueError('Positive record and asset ids required')
    for key in ('source', 'target'):
        path = document.get(key)
        if not isinstance(path, str) or os.path.normpath(path) != path or not path.lower().endswith('.mkv') or \
                any(ord(char) < 32 or ord(char) == 127 for char in path):
            raise ValueError('Canonical MKV path required')
    source, target = Path(document['source']), Path(document['target'])
    if source.parts[:3] != ('/', 'videos', 'Films') or len(source.parts) != 5:
        raise ValueError('Source must be a standalone film in one genre directory')
    film = document.get('category') == 'film' and target.parts[:3] == ('/', 'videos', 'Films') and len(target.parts) == 5
    documentary = document.get('category') == 'documentary' and target.parts[:3] == ('/', 'videos', 'Documentaires') and len(target.parts) == 4
    if not (film or documentary) or source.parent == target.parent:
        raise ValueError('Target does not match the authorized category')
    expected = document.get('identity')
    if not isinstance(expected, dict) or set(expected) != {'dev', 'ino', 'size', 'mtime_ns', 'ctime_ns'} or \
            any(type(value) is not int or value < 0 for value in expected.values()):
        raise ValueError('A complete integer file identity is required')
    return CrossDirectoryRename(source, target, expected)


def load_worker(manifest, socket_path):
    worker = base.load_worker(manifest, socket_path, factory=worker_from_request)
    worker.sandbox_runtime = socket_path.parent
    return worker


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise ValueError('A root-owned manifest and runtime socket are required')
        sys.exit(base.serve(Path(sys.argv[1]), Path(sys.argv[2]), loader=load_worker))
    except Exception as error:
        print(json.dumps({'status': 'failed', 'error_class': type(error).__name__, 'error': str(error)}), file=sys.stderr)
        sys.exit(1)
