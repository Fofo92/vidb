"""No sudo, production service, queue mutation or real capture in these tests."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'script'))
from bridges import checks, cli, commands, config


class BridgesTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.data = {'version': 1, 'owner': 'pascal', 'encoder_root': str(self.root / 'encoder'),
                     'ruby': '/usr/bin/ruby', 'url': 'https://zeus.fodiman.fr',
                     'deployed_code': '/srv/vidb/current', 'user_id': None}

    def test_configuration_round_trip_is_private_and_has_no_secret(self):
        path = self.root / 'settings/bridges.json'
        config.save(path, self.data)
        self.assertEqual(self.data, config.load(path))
        self.assertEqual(0o600, path.stat().st_mode & 0o777)
        self.assertNotIn('token', path.read_text())

    def test_unknown_keys_cannot_store_a_token_in_central_configuration(self):
        with self.assertRaises(config.BridgeError):
            config.validate(dict(self.data, token='secret'))

    def test_unsafe_urls_accounts_and_paths_are_rejected(self):
        for changes in ({'url': 'http://example.com'}, {'url': 'https://user:password@example.com'},
                        {'url': 'https://example.com/path'}, {'owner': 'pascal;id'},
                        {'ruby': '/tmp/ruby\ncommand'}, {'user_id': True}):
            with self.subTest(changes=changes), self.assertRaises(config.BridgeError):
                config.validate(dict(self.data, **changes))

    def test_configuration_symlinks_and_public_files_are_rejected(self):
        target = self.root / 'real.json'
        config.save(target, self.data)
        path = self.root / 'link.json'
        path.symlink_to(target)
        with self.assertRaises(config.BridgeError):
            config.load(path)
        with self.assertRaises(config.BridgeError):
            config.save(path, self.data)
        target.chmod(0o644)
        with self.assertRaises(config.BridgeError):
            config.load(target)

    def test_install_is_a_plan_without_apply_and_never_touches_quarantine(self):
        with patch.object(commands, 'execute') as execute:
            rows = commands.install(self.root, self.data, 'all')
        execute.assert_not_called()
        self.assertTrue(any('copy-trash' in row for row in rows))
        self.assertFalse(any('quarantine' in row for row in rows))

    def test_default_install_delegates_existing_commands_and_does_not_restart_anything(self):
        with patch.object(commands, 'execute', return_value='{"changed":false}') as execute, \
                patch.object(commands, 'install_kaffeine') as kaffeine:
            commands.install(self.root, self.data, 'all', apply=True)
        kaffeine.assert_called_once_with(self.root, 'pascal')
        calls = [call.args[0] for call in execute.call_args_list]
        self.assertTrue(any('install-encoder-project-bridge' in part for cmd in calls for part in cmd))
        self.assertTrue(any('install-copy-trash-bridge' in part for cmd in calls for part in cmd))
        self.assertFalse(any('quarantine' in part or 'systemctl' in part for cmd in calls for part in cmd))
        self.assertTrue(any('--deployed-code' in cmd for cmd in calls))

    def test_kaffeine_sudoers_is_validated_before_install_and_keeps_its_own_permission(self):
        source = self.root / 'ops/vidb-kaffeine-busctl'
        source.parent.mkdir()
        source.write_text('# existing restricted helper')
        calls, rules = [], []
        def execute(command, **_kwargs):
            calls.append(command)
            if '-cf' in command:
                rules.append(Path(command[-1]).read_text())
            return ''
        with patch.object(commands, 'execute', side_effect=execute):
            commands.install_kaffeine(self.root, 'pascal')
        self.assertIn('visudo', calls[0][1])
        self.assertEqual('vidb ALL=(pascal) NOPASSWD: /usr/local/libexec/vidb-kaffeine-busctl *\n', rules[0])
        self.assertIn('0440', calls[-1])

    def test_quarantine_install_is_explicit_and_uses_the_configured_ruby_environment(self):
        with patch.object(commands, 'execute', return_value='') as execute:
            commands.install(self.root, self.data, 'quarantine', apply=True)
        execute.assert_called_once()
        self.assertIn('install-quarantine-timer', execute.call_args.args[0][-1])
        self.assertTrue(execute.call_args.kwargs['env']['PATH'].startswith('/usr/bin' + os.pathsep))

    def test_install_failure_reports_the_component_and_stops(self):
        with patch.object(commands, 'install_component', side_effect=config.BridgeError('Refus')) as install, \
                self.assertRaises(config.BridgeError) as error:
            commands.install(self.root, self.data, 'all', apply=True)
        install.assert_called_once()
        self.assertIn('encoder-project', str(error.exception))

    def test_environment_update_preserves_secrets_and_other_variables_and_is_idempotent(self):
        env = self.root / 'vidb.env'
        original = '# comment\nSECRET_KEY_BASE=keep-this-exactly\nVIDB_KAFFEINE_USER=old\n'
        env.write_text(original)
        env.chmod(0o640)
        code = commands.ENVIRONMENT_UPDATE.replace("Path('/etc/vidb/vidb.env')", f'Path({str(env)!r})')
        result = subprocess.run([sys.executable, '-c', code, 'pascal', 'kaffeine,copy-trash'],
                                capture_output=True, text=True, check=True)
        self.assertTrue(json.loads(result.stdout)['changed'])
        self.assertIn('SECRET_KEY_BASE=keep-this-exactly\n', env.read_text())
        self.assertIn('VIDB_COPY_TRASH_USER=pascal\n', env.read_text())
        self.assertNotIn('keep-this-exactly', result.stdout + result.stderr)
        self.assertEqual(0o640, env.stat().st_mode & 0o777)
        result = subprocess.run([sys.executable, '-c', code, 'pascal', 'kaffeine,copy-trash'],
                                capture_output=True, text=True, check=True)
        self.assertFalse(json.loads(result.stdout)['changed'])

    def test_partial_install_environment_update_preserves_the_other_bridge(self):
        env = self.root / 'vidb.env'
        env.write_text('VIDB_KAFFEINE_USER=another\nVIDB_KAFFEINE_BRIDGE=0\n')
        code = commands.ENVIRONMENT_UPDATE.replace("Path('/etc/vidb/vidb.env')", f'Path({str(env)!r})')
        subprocess.run([sys.executable, '-c', code, 'pascal', 'copy-trash'],
                       capture_output=True, check=True)
        self.assertIn('VIDB_KAFFEINE_USER=another\n', env.read_text())
        self.assertIn('VIDB_KAFFEINE_BRIDGE=0\n', env.read_text())

    def test_failed_subprocess_never_displays_its_captured_secret(self):
        with patch.object(commands.subprocess, 'run', return_value=types.SimpleNamespace(returncode=1,
                          stdout='token=secret', stderr='SECRET_KEY_BASE=secret')):
            with self.assertRaises(config.BridgeError) as error:
                commands.execute(['false'])
        self.assertNotIn('secret', str(error.exception))

    def test_credential_probe_compares_secrets_without_emitting_them(self):
        server, client = self.root / 'server.json', self.root / 'client.json'
        document = {'url': self.data['url'], 'token': 'a' * 64, 'user_id': 1}
        for path in (server, client):
            path.write_text(json.dumps(document))
        code = checks.CREDENTIAL_PROBE.replace("'/srv/vidb/shared/encoder-bridge/server.json'", repr(str(server)))
        command = [sys.executable, '-c', code, str(client), self.data['url'], '1']
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        self.assertEqual({'status': 'ready'}, json.loads(result.stdout))
        self.assertNotIn('a' * 64, result.stdout + result.stderr)
        client.write_text(json.dumps(dict(document, token='b' * 64)))
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(0, result.returncode)
        self.assertNotIn('a' * 64, result.stdout + result.stderr)
        self.assertNotIn('b' * 64, result.stdout + result.stderr)

    def test_diagnostic_continues_after_a_failure_and_reports_all_components(self):
        with patch.object(checks, 'check_credentials', side_effect=config.BridgeError('Absent')), \
                patch.object(checks, 'check_environment', return_value='ok'), \
                patch.object(checks, 'check_kaffeine', return_value='ok'), \
                patch.object(checks, 'check_trash', return_value='ok'), \
                patch.object(checks, 'check_quarantine', return_value='ok'):
            rows = checks.check(self.data)
        self.assertEqual(6, len(rows))
        self.assertEqual('error', rows[0]['status'])
        self.assertEqual('ok', rows[3]['status'])
        self.assertEqual('info', rows[-1]['status'])

    def test_kaffeine_diagnostic_can_only_read_the_schedule(self):
        with patch.object(checks, 'execute', return_value='{"data":[]}') as execute:
            checks.check_kaffeine(self.data)
        command = execute.call_args.args[0]
        self.assertEqual('ListProgramSchedule', command[-1])
        self.assertNotIn('ScheduleProgram', command)
        self.assertNotIn('RemoveProgram', command)

    def test_trash_diagnostic_sends_no_media_path_or_mutating_operation(self):
        with patch.object(checks, 'execute', return_value='{"status":"ready"}') as execute:
            checks.check_trash(self.data)
        self.assertEqual({'operation': 'health'}, json.loads(execute.call_args.kwargs['input']))

    def test_environment_diagnostic_detects_a_restart_still_needed(self):
        values = {'VIDB_KAFFEINE_BRIDGE': '1', 'VIDB_KAFFEINE_USER': 'pascal', 'VIDB_COPY_TRASH_USER': 'pascal'}
        response = {'configured': values, 'runtime': dict(values, VIDB_COPY_TRASH_USER=None)}
        with patch.object(checks, 'execute', return_value=json.dumps(response)), self.assertRaises(config.BridgeError):
            checks.check_environment(self.data)

    def test_quarantine_diagnostic_never_runs_a_sweep_or_enables_a_unit(self):
        with patch.object(checks, 'execute', side_effect=['ActiveState=active\nUnitFileState=enabled\n',
                                                        'Result=success\nExecMainStatus=0\n']) as execute:
            checks.check_quarantine(self.data)
        for call in execute.call_args_list:
            self.assertEqual(['systemctl', '--user', 'show'], call.args[0][:3])

    def test_cli_returns_failure_for_a_failed_diagnostic_without_printing_secrets(self):
        path = self.root / 'bridges.json'
        config.save(path, self.data)
        rows = [{'component': 'copy-trash', 'status': 'error', 'message': 'Indisponible'}]
        with patch.object(cli.os, 'getuid', return_value=os.getuid() or 1000), \
                patch.object(cli.pwd, 'getpwuid', return_value=types.SimpleNamespace(pw_name='pascal')), \
                patch.object(cli, 'load', return_value=self.data), patch.object(cli.checks, 'check', return_value=rows), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            status = cli.main(['--config', str(path), 'check', '--json'])
        self.assertEqual(1, status)
        self.assertEqual(rows, json.loads(output.getvalue())['checks'])


if __name__ == '__main__':
    unittest.main()
