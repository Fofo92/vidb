import json
import os
from pathlib import Path
import subprocess
import tempfile

from .config import BridgeError

COMPONENTS = ('encoder-project', 'kaffeine', 'copy-trash')


def execute(command, *, timeout=30, input=None, cwd=None, env=None):
    try:
        result = subprocess.run(command, input=input, cwd=cwd, env=env,
                                capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise BridgeError('Commande indisponible ou délai dépassé.') from error
    if result.returncode:
        # Never print captured diagnostics: a subprocess may include credentials.
        raise BridgeError(f'Commande refusée (code {result.returncode}) ; vérifier accès, service et configuration.')
    return result.stdout


ENVIRONMENT_UPDATE = r'''
import json, os, re, stat, sys, tempfile
from pathlib import Path
owner = sys.argv[1]
assert re.fullmatch(r'[a-z_][a-z0-9_-]*', owner)
path = Path('/etc/vidb/vidb.env')
st = path.lstat()
assert stat.S_ISREG(st.st_mode) and not path.is_symlink()
assert st.st_size < 1048576
components = sys.argv[2].split(',')
assert set(components) <= {'kaffeine','copy-trash','encoder-project'}
values = {}
if 'kaffeine' in components:
    values.update(VIDB_KAFFEINE_BRIDGE='1', VIDB_KAFFEINE_USER=owner)
if 'copy-trash' in components:
    values['VIDB_COPY_TRASH_USER'] = owner
original = path.read_text()
lines, remaining = [], dict(values)
for line in original.splitlines(keepends=True):
    match = re.match(r'^\s*(?:export\s+)?(VIDB_KAFFEINE_BRIDGE|VIDB_KAFFEINE_USER|VIDB_COPY_TRASH_USER)\s*=', line)
    if match and match.group(1) in values:
        key = match.group(1)
        if key in remaining:
            lines.append(key + '=' + remaining.pop(key) + '\n')
    else:
        lines.append(line)
if remaining and lines and not lines[-1].endswith('\n'):
    lines.append('\n')
lines.extend(key + '=' + value + '\n' for key, value in remaining.items())
content = ''.join(lines)
if content != original:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as file:
            temporary = Path(file.name)
            os.fchown(file.fileno(), st.st_uid, st.st_gid)
            os.fchmod(file.fileno(), stat.S_IMODE(st.st_mode))
            file.write(content)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, path)
    finally:
        if temporary and temporary.exists(): temporary.unlink()
print(json.dumps({'changed': content != original}))
'''


def install_kaffeine(root, owner):
    source = root / 'ops/vidb-kaffeine-busctl'
    if not source.is_file():
        raise BridgeError('Programme Kaffeine absent du dépôt vidb.')
    with tempfile.TemporaryDirectory(prefix='vidb-bridges-') as directory:
        rule = Path(directory) / 'sudoers'
        rule.write_text(f'vidb ALL=({owner}) NOPASSWD: /usr/local/libexec/vidb-kaffeine-busctl *\n')
        execute(['sudo', '/usr/sbin/visudo', '-cf', str(rule)])
        execute(['sudo', 'install', '-D', '-o', 'root', '-g', 'root', '-m', '0755',
                 str(source), '/usr/local/libexec/vidb-kaffeine-busctl'])
        execute(['sudo', 'install', '-o', 'root', '-g', 'root', '-m', '0440',
                 str(rule), '/etc/sudoers.d/vidb-kaffeine'])


def install(root, config, selected, apply=False):
    components = COMPONENTS if selected == 'all' else (selected,)
    results = []
    for component in components:
        if not apply:
            results.append(f'Prévu : {component}')
            continue
        try:
            install_component(root, config, component)
        except BridgeError as error:
            done = ', '.join(results) or 'aucune étape terminée'
            raise BridgeError(f'{component} : {error} Étapes précédentes : {done}.') from error
        results.append(f'Installé : {component}')
    if any(component in ('kaffeine', 'copy-trash') for component in components):
        if apply:
            result = json.loads(execute(['sudo', '/usr/bin/python3', '-c', ENVIRONMENT_UPDATE,
                                         config['owner'], ','.join(components)]))
            if result['changed']:
                results.append('Environnement mis à jour : redémarrer uniquement vidb pour sa prise en compte.')
        else:
            results.append('Prévu : synchroniser les trois variables non secrètes dans /etc/vidb/vidb.env.')
    return results


def install_component(root, config, component):
    if component == 'kaffeine':
        install_kaffeine(root, config['owner'])
    elif component == 'encoder-project':
        command = [str(root / 'bin/install-encoder-project-bridge'), config['url']]
        if config.get('user_id'):
            command.append(str(config['user_id']))
        execute(command, timeout=120, cwd=root)
    elif component == 'copy-trash':
        execute(['/usr/bin/python3', str(root / 'bin/install-copy-trash-bridge'),
                 '--encoder-root', config['encoder_root'], '--ruby', config['ruby'],
                 '--deployed-code', config['deployed_code']], timeout=120)
    elif component == 'quarantine':
        environment = dict(os.environ)
        environment['PATH'] = str(Path(config['ruby']).parent) + os.pathsep + os.environ.get('PATH', '')
        environment['BUNDLE_GEMFILE'] = str(Path(config['encoder_root']) / 'Gemfile')
        execute(['/usr/bin/python3', str(Path(config['encoder_root']) / 'bin/install-quarantine-timer')],
                timeout=120, cwd=config['encoder_root'], env=environment)
