import json
import os
from pathlib import Path

from .commands import execute
from .config import BridgeError

CREDENTIAL_PROBE = r'''
import hmac, json, re, stat, sys
from pathlib import Path
def read(path):
    path = Path(path)
    st = path.lstat()
    assert stat.S_ISREG(st.st_mode) and st.st_size <= 4096 and not path.is_symlink()
    return json.loads(path.read_text())
server, client = read('/srv/vidb/shared/encoder-bridge/server.json'), read(sys.argv[1])
assert all(isinstance(d.get('token'), str) and re.fullmatch('[0-9a-f]{64}', d['token']) for d in (server, client))
assert hmac.compare_digest(server['token'], client['token'])
assert server.get('url') == client.get('url') == sys.argv[2]
assert type(server.get('user_id')) is int and server['user_id'] > 0
assert client.get('user_id', server['user_id']) == server['user_id']
assert not sys.argv[3] or server['user_id'] == int(sys.argv[3])
print(json.dumps({'status':'ready'}))
'''

ENVIRONMENT_PROBE = r'''
import json, re, shlex, subprocess
from pathlib import Path
keys = ('VIDB_KAFFEINE_BRIDGE','VIDB_KAFFEINE_USER','VIDB_COPY_TRASH_USER')
text = Path('/etc/vidb/vidb.env').read_text()
assert len(text) < 1048576
configured = {}
for line in text.splitlines():
    match = re.match(r'^\s*(?:export\s+)?(VIDB_KAFFEINE_BRIDGE|VIDB_KAFFEINE_USER|VIDB_COPY_TRASH_USER)\s*=(.*)$', line)
    if match:
        words = shlex.split(match.group(2), comments=True)
        configured[match.group(1)] = words[0] if len(words) == 1 else ''
pid = subprocess.check_output(['/usr/bin/systemctl','show','vidb','--property=MainPID','--value'], text=True).strip()
assert pid.isdecimal() and int(pid) > 0
raw = Path('/proc/' + pid + '/environ').read_bytes()
assert len(raw) <= 1048576
runtime = dict(part.decode(errors='replace').split('=',1) for part in raw.split(b'\0') if b'=' in part)
print(json.dumps({'configured':configured, 'runtime':{key:runtime.get(key) for key in keys}}))
'''


def check_credentials(config):
    client = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'video_encoder/vidb.json'
    result = json.loads(execute(['sudo', '-n', '/usr/bin/python3', '-c', CREDENTIAL_PROBE,
                                str(client), config['url'], str(config.get('user_id') or '')]))
    if result.get('status') != 'ready':
        raise BridgeError('Identifiants des deux côtés non concordants.')
    return 'URL, compte et secret concordants ; secret non affiché.'


def check_environment(config):
    result = json.loads(execute(['sudo', '-n', '/usr/bin/python3', '-c', ENVIRONMENT_PROBE]))
    expected = {'VIDB_KAFFEINE_BRIDGE': '1', 'VIDB_KAFFEINE_USER': config['owner'],
                'VIDB_COPY_TRASH_USER': config['owner']}
    if result.get('configured') != expected:
        raise BridgeError('Environnement serveur à synchroniser avec bin/bridges install --apply.')
    if result.get('runtime') != expected:
        raise BridgeError('Environnement installé mais pas encore chargé : redémarrer uniquement vidb.')
    return 'Environnement serveur concordant, chargé par vidb.'


def check_kaffeine(config):
    output = execute(['sudo', '-n', '-u', 'vidb', '--', '/usr/bin/sudo', '-n', '-u', config['owner'],
                      '--', '/usr/local/libexec/vidb-kaffeine-busctl', 'ListProgramSchedule'])
    if not isinstance(json.loads(output), (dict, list)):
        raise BridgeError('Réponse Kaffeine invalide.')
    return 'Lecture des programmations réussie depuis le compte vidb.'


def check_trash(config):
    output = execute(['sudo', '-n', '-u', 'vidb', '--', '/usr/bin/sudo', '-n', '-u', config['owner'],
                      '--', '/usr/local/libexec/vidb-copy-trash'], input='{"operation":"health"}\n')
    if json.loads(output).get('status') != 'ready':
        raise BridgeError('Passerelle de corbeille non prête.')
    return 'Accès depuis vidb, volume et lecture seule de la file validés ; aucun fichier déplacé.'


def check_quarantine(_config):
    output = execute(['systemctl', '--user', 'show', 'video-encoder-quarantine.timer',
                      '--property=ActiveState,UnitFileState,NextElapseUSecRealtime'])
    data = dict(line.split('=', 1) for line in output.splitlines() if '=' in line)
    if data.get('ActiveState') != 'active' or data.get('UnitFileState') != 'enabled':
        raise BridgeError('Timer de quarantaine non actif ou non activé au démarrage de session.')
    service = execute(['systemctl', '--user', 'show', 'video-encoder-quarantine.service',
                       '--property=Result,ExecMainStatus'])
    state = dict(line.split('=', 1) for line in service.splitlines() if '=' in line)
    if state.get('Result') not in (None, '', 'success') or state.get('ExecMainStatus', '0') != '0':
        raise BridgeError('Le dernier passage de quarantaine a échoué ; consulter son journal utilisateur.')
    return 'Timer actif ; prochain contrôle : ' + data.get('NextElapseUSecRealtime', 'non communiqué')


def check(config):
    probes = (('encoder-project', check_credentials), ('environment', check_environment),
              ('kaffeine', check_kaffeine), ('copy-trash', check_trash), ('quarantine', check_quarantine))
    results = []
    for name, probe in probes:
        try:
            results.append({'component': name, 'status': 'ok', 'message': probe(config)})
        except (BridgeError, ValueError, KeyError, TypeError, AttributeError) as error:
            message = str(error) if isinstance(error, BridgeError) else 'Réponse de diagnostic invalide.'
            results.append({'component': name, 'status': 'error', 'message': message})
    results.append({'component': 'relocation', 'status': 'info',
                    'message': 'Workers ponctuels liés à un plan ; aucun démarrage automatique.'})
    return results
