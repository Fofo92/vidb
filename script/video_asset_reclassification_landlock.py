"""Fail-closed Linux x86-64 Landlock write confinement for the fixed worker."""
import ctypes
import os
import platform


class Ruleset(ctypes.Structure):
    _fields_ = [('handled_access_fs', ctypes.c_uint64)]


class PathRule(ctypes.Structure):
    _pack_ = 1
    _fields_ = [('allowed_access', ctypes.c_uint64), ('parent_fd', ctypes.c_int32)]


WRITE_ACCESS = (1 << 1) | sum(1 << bit for bit in range(4, 15))


def restrict_writes(directory_fds):
    """Irreversibly restrict this thread; call only inside the one-shot worker."""
    if platform.machine().lower() not in ('x86_64', 'amd64'):
        raise RuntimeError('Only the verified Linux x86-64 syscall ABI is supported')
    if len(directory_fds) != 3:
        raise ValueError('Source, destination and private runtime descriptors required')
    libc = ctypes.CDLL(None, use_errno=True)
    libc.syscall.restype = ctypes.c_long

    def syscall(number, *arguments):
        result = libc.syscall(ctypes.c_long(number), *arguments)
        if result < 0:
            code = ctypes.get_errno()
            raise OSError(code, os.strerror(code))
        return result

    abi = syscall(444, ctypes.c_void_p(), ctypes.c_size_t(0), ctypes.c_uint(1))
    if abi < 3:
        raise RuntimeError('Landlock ABI >= 3 is required; no unconfined fallback')
    ruleset = Ruleset(WRITE_ACCESS)
    descriptor = syscall(444, ctypes.byref(ruleset), ctypes.c_size_t(ctypes.sizeof(ruleset)), ctypes.c_uint(0))
    try:
        for parent in directory_fds:
            rule = PathRule(WRITE_ACCESS, parent)
            syscall(445, ctypes.c_int(descriptor), ctypes.c_int(1), ctypes.byref(rule), ctypes.c_uint(0))
        if libc.prctl(ctypes.c_int(38), ctypes.c_ulong(1), ctypes.c_ulong(0), ctypes.c_ulong(0), ctypes.c_ulong(0)):
            code = ctypes.get_errno()
            raise OSError(code, os.strerror(code))
        syscall(446, ctypes.c_int(descriptor), ctypes.c_uint(0))
    finally:
        os.close(descriptor)
    return abi
