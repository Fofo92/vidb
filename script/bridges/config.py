import json
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import urlsplit


class BridgeError(Exception):
    pass


def default_path():
    return Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'vidb/bridges.json'


def validate(data):
    required = {'version', 'owner', 'encoder_root', 'ruby', 'url', 'deployed_code'}
    if not isinstance(data, dict) or set(data) - required - {'user_id'} or not required <= set(data):
        raise BridgeError('Configuration inconnue ou incomplète ; utiliser configure.')
    if type(data['version']) is not int or data['version'] != 1:
        raise BridgeError('Version de configuration inconnue.')
    if not isinstance(data['owner'], str) or not re.fullmatch(r'[a-z_][a-z0-9_-]*', data['owner']):
        raise BridgeError('Utilisateur local invalide.')
    for field in ('encoder_root', 'ruby', 'deployed_code'):
        value = data[field]
        if not isinstance(value, str) or not Path(value).is_absolute() or any(c in value for c in '\n\r\0'):
            raise BridgeError(f'Chemin invalide : {field}.')
    try:
        if not isinstance(data['url'], str) or any(c in data['url'] for c in '\n\r\0\t '):
            raise ValueError('URL invalide')
        url = urlsplit(data['url'])
        valid = (url.scheme == 'https' and url.hostname and url.username is None and url.password is None
                 and url.path in ('', '/') and not url.query and not url.fragment)
        _ = url.port
    except (ValueError, TypeError, AttributeError):
        valid = False
    if not valid:
        raise BridgeError('URL HTTPS de vidb invalide, sans identifiants ni chemin.')
    if data.get('user_id') is not None and (type(data['user_id']) is not int or data['user_id'] <= 0):
        raise BridgeError('Identifiant de compte vidb invalide.')
    return data


def load(path):
    try:
        stat = path.lstat()
        if path.is_symlink() or not path.is_file() or stat.st_uid != os.getuid() or stat.st_mode & 0o077:
            raise BridgeError('Configuration privée requise : fichier régulier du compte courant, mode 0600.')
        if stat.st_size > 16_384:
            raise BridgeError('Configuration trop volumineuse.')
        return validate(json.loads(path.read_text()))
    except (OSError, ValueError) as error:
        raise BridgeError('Configuration absente ou illisible ; utiliser bin/bridges configure.') from error


def save(path, data):
    validate(data)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.parent.is_symlink() or path.is_symlink():
        raise BridgeError('Lien symbolique refusé pour la configuration.')
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.bridges-', delete=False) as file:
            temporary = Path(file.name)
            os.fchmod(file.fileno(), 0o600)
            json.dump(data, file, ensure_ascii=False, indent=2)
            file.write('\n')
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, path)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()
