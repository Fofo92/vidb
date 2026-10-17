#!/usr/bin/env python3
"""One root-pinned same-directory MKV rename; no database or general command execution."""
import ctypes
import errno
import json
import os
from pathlib import Path
import pwd
import socket
import stat
import struct
import sys



def identity(info):
    return {'dev': info.st_dev, 'ino': info.st_ino, 'size': info.st_size,
            'mtime_ns': info.st_mtime_ns, 'ctime_ns': info.st_ctime_ns}


class FixedRename:
    def __init__(self, source, target, expected):
        self.source = Path(source)
        self.target = Path(target)
        self.expected = expected
        self.phase = 'before_rename'
        self.libc = ctypes.CDLL(None, use_errno=True)
        self.native = self.libc.renameat2
        self.native.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        self.native.restype = ctypes.c_int

    def open_parent(self):
        flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_DIRECTORY
        if not self.source.is_absolute() or self.source.parent != self.target.parent or self.source == self.target:
            raise ValueError('Fixed distinct files in one absolute directory required')
        if any(part in ('.', '..') for part in self.source.parts + self.target.parts):
            raise ValueError('Noncanonical path')
        fd = os.open('/', flags)
        try:
            for part in self.source.parent.parts[1:]:
                child = os.open(part, flags, dir_fd=fd)
                os.close(fd)
                fd = child
            return fd
        except BaseException:
            os.close(fd)
            raise

    def checked_source(self, parent):
        fd = os.open(self.source.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or identity(info) != self.expected:
                raise ValueError('Source identity differs from the pinned preview')
            if os.fstatvfs(parent).f_flag & os.ST_RDONLY:
                raise ValueError('Source filesystem is read-only')
            return fd
        except BaseException:
            os.close(fd)
            raise

    def validate_request(self, request):
        valid = isinstance(request, dict) and request.get('source') == str(self.source) and \
                request.get('target') == str(self.target) and request.get('identity') == self.expected
        if not valid or request.get('op') not in ('probe', 'rename'):
            raise ValueError('Request outside the single authorized rename')

    def execute(self, request):
        self.validate_request(request)
        parent = self.open_parent()
        source = None
        try:
            source = self.checked_source(parent)
            try:
                os.stat(self.target.name, dir_fd=parent, follow_symlinks=False)
            except FileNotFoundError:
                pass
            else:
                raise FileExistsError(errno.EEXIST, 'Destination occupied')
            if request['op'] == 'probe':
                return {'status': 'ready'}
            result = self.native(parent, os.fsencode(self.source.name), parent, os.fsencode(self.target.name), 1)
            if result != 0:
                code = ctypes.get_errno()
                raise OSError(code, os.strerror(code))
            self.phase = 'after_rename'
            os.fsync(parent)
            expected = {key: value for key, value in self.expected.items() if key != 'ctime_ns'}
            for info in (os.stat(self.target.name, dir_fd=parent, follow_symlinks=False), os.lstat(self.target)):
                actual = {key: value for key, value in identity(info).items() if key != 'ctime_ns'}
                if not stat.S_ISREG(info.st_mode) or actual != expected:
                    raise ValueError('Target identity changed after rename')
            return {'status': 'renamed'}
        finally:
            if source is not None:
                os.close(source)
            os.close(parent)


def load_worker(manifest, socket_path):
    if manifest.name != 'plan.json' or manifest.parent != socket_path.parent:
        raise ValueError('The manifest must be plan.json beside the runtime socket')
    fd = os.open(manifest, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as file:
        info = os.fstat(file.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError('The manifest must be a regular root-owned mode-0600 file')
        data = file.read(16385)
    if len(data) > 16384:
        raise ValueError('Manifest too large')
    return worker_from_request(json.loads(data))


def worker_from_request(document):
    if not isinstance(document, dict) or document.get('format') != 'vidb.relocation_request' or \
            type(document.get('version')) is not int or document.get('version') != 1 or \
            document.get('execution_authorized') is not True:
        raise ValueError('An explicitly authorized version-1 request is required')
    if document.get('root') != '/videos':
        raise ValueError('Only the expected /videos root is permitted')
    for key in ('record_id', 'asset_id'):
        if type(document.get(key)) is not int or document[key] <= 0:
            raise ValueError('Positive record and asset ids required')
    paths = [document.get(key) for key in ('source', 'target')]
    for path in paths:
        if not isinstance(path, str) or not path.startswith('/videos/Films/') or os.path.normpath(path) != path or \
                any(ord(char) < 32 or ord(char) == 127 for char in path) or not path.lower().endswith('.mkv'):
            raise ValueError('Canonical MKV paths inside /videos/Films required')
    if paths[0] == paths[1] or Path(paths[0]).parent != Path(paths[1]).parent:
        raise ValueError('Distinct paths in the same directory required')
    expected = document.get('identity')
    if not isinstance(expected, dict) or set(expected) != {'dev', 'ino', 'size', 'mtime_ns', 'ctime_ns'} or \
            any(type(value) is not int or value < 0 for value in expected.values()):
        raise ValueError('A complete integer file identity is required')
    return FixedRename(paths[0], paths[1], expected)


def serve(manifest, path):
    uid = pwd.getpwnam('vidb').pw_uid
    gid = pwd.getpwnam('vidb').pw_gid
    parent = path.parent
    info = os.lstat(parent)
    valid = os.geteuid() == 0 and os.getegid() == gid and path.name == 'worker.sock' and \
            str(parent).startswith('/run/vidb-relocation-') and parent.resolve() == parent and \
            stat.S_ISDIR(info.st_mode) and info.st_uid == 0 and info.st_gid == gid and not info.st_mode & 0o027
    if not valid:
        raise ValueError('Expected a root-owned private runtime directory and root:vidb worker')
    worker = load_worker(manifest, path)
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(str(path))
        os.chmod(path, 0o660)
        server.listen(1)
        server.settimeout(90)
        try:
            for _ in range(2):
                connection, _ = server.accept()
                with connection:
                    connection.settimeout(30)
                    peer_uid = struct.unpack('3i', connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))[1]
                    if peer_uid != uid:
                        raise PermissionError('Only the vidb process may request the fixed rename')
                    try:
                        line = connection.makefile('rb').readline(16385)
                        if len(line) > 16384 or not line.endswith(b'\n'):
                            raise ValueError('Invalid request framing')
                        request = json.loads(line)
                        response = worker.execute(request)
                    except Exception as error:
                        response = {'status': 'failed', 'phase': worker.phase,
                                    'error_class': type(error).__name__, 'error': str(error)}
                        connection.sendall((json.dumps(response) + '\n').encode())
                        return 1
                    connection.sendall((json.dumps(response) + '\n').encode())
                    if response['status'] == 'renamed':
                        return 0
        finally:
            path.unlink(missing_ok=True)
    return 1


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise ValueError('A root-owned plan.json and a runtime socket path are required')
        sys.exit(serve(Path(sys.argv[1]), Path(sys.argv[2])))
    except Exception as error:
        print(json.dumps({'status': 'failed', 'error_class': type(error).__name__, 'error': str(error)}), file=sys.stderr)
        sys.exit(1)
