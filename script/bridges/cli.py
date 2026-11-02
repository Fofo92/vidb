import argparse
import json
import os
from pathlib import Path
import pwd
import sys

from . import checks, commands
from .config import BridgeError, default_path, load, save


def parser():
    result = argparse.ArgumentParser(description='Installer, configurer et diagnostiquer les passerelles vidb.')
    result.add_argument('--config', type=Path, default=default_path())
    sub = result.add_subparsers(dest='action', required=True)
    configure = sub.add_parser('configure', help='Enregistrer les chemins et paramètres non secrets.')
    configure.add_argument('--encoder-root', type=Path, required=True)
    configure.add_argument('--ruby', type=Path, required=True)
    configure.add_argument('--url', required=True)
    configure.add_argument('--user-id', type=int)
    configure.add_argument('--deployed-code', type=Path, default=Path('/srv/vidb/current'))
    install = sub.add_parser('install', help='Afficher le plan, ou installer avec --apply.')
    install.add_argument('component', nargs='?', default='all', choices=(*commands.COMPONENTS, 'all', 'quarantine'))
    install.add_argument('--apply', action='store_true')
    diagnostic = sub.add_parser('check', help='Diagnostic sans modification, sans affichage de secrets.')
    diagnostic.add_argument('--json', action='store_true')
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if os.getuid() == 0:
            raise BridgeError('Lancer comme propriétaire de video_encoder, sans sudo ; sudo sera utilisé au besoin.')
        owner = pwd.getpwuid(os.getuid()).pw_name
        if args.action == 'configure':
            data = {'version': 1, 'owner': owner, 'encoder_root': str(args.encoder_root.resolve(strict=True)),
                    'ruby': str(args.ruby.resolve(strict=True)), 'url': args.url.rstrip('/'),
                    'deployed_code': str(args.deployed_code.absolute()), 'user_id': args.user_id}
            if not Path(data['ruby']).is_file() or not os.access(data['ruby'], os.X_OK):
                raise BridgeError('Le Ruby choisi n’est pas exécutable.')
            if not (Path(data['encoder_root']) / 'config/video_encoder.yml').is_file():
                raise BridgeError('Dépôt video_encoder non reconnu.')
            save(args.config, data)
            print(f'Configuration enregistrée : {args.config}. Aucun secret copié.')
            return 0
        config = load(args.config)
        if config['owner'] != owner:
            raise BridgeError('La configuration appartient à un autre compte ; exécuter configure avec le propriétaire.')
        root = Path(__file__).resolve().parents[2]
        if args.action == 'install':
            for line in commands.install(root, config, args.component, apply=args.apply):
                print(line)
            return 0
        results = checks.check(config)
        if args.json:
            print(json.dumps({'checks': results}, ensure_ascii=False, indent=2))
        else:
            for row in results:
                print(f"{row['status'].upper():5} {row['component']} — {row['message']}")
        return int(any(row['status'] == 'error' for row in results))
    except (BridgeError, OSError) as error:
        print(f'Passerelles : {error}', file=sys.stderr)
        return 1
    except ValueError:
        print('Passerelles : réponse de commande invalide ; lancer le diagnostic.', file=sys.stderr)
        return 1
