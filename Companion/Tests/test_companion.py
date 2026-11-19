import asyncio
import gzip
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
import uuid
import zlib
import zipfile
import hashlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from companion import Companion, TransferError, app_for, inspect_clone, ROOT
from aiohttp.test_utils import TestClient, TestServer

HEADER = bytes.fromhex('47474759000000004e4f4c43000000000001000000000000')
DEVICE = 'a' * 64


def archive(name='Example clone', clone_id=None, extra=None, corrupt=False):
    identity = clone_id or str(uuid.uuid4())
    metadata = json.dumps({'clone_uuid': identity, 'clone_name': name, 'clone_category': 'amp'}).encode()
    manifest = json.dumps([{'path': 'output/data/stadium-database-metadata.json', 'size': len(metadata), 'checksum': zlib.crc32(metadata) + int(corrupt)}]).encode()
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode='w') as tar:
        for filename, value in [('manifest.json', manifest), ('output/data/stadium-database-metadata.json', metadata)] + (extra or []):
            item = tarfile.TarInfo(filename)
            item.size = len(value)
            tar.addfile(item, io.BytesIO(value))
    return HEADER + gzip.compress(out.getvalue())


class FakeFile(io.BytesIO):
    def __init__(self, client, path, write):
        super().__init__(b'' if write else client.files[path])
        self.client, self.path, self.write_mode = client, path, write
    def close(self):
        if self.closed:
            return
        if self.write_mode:
            self.client.files[self.path] = self.getvalue()
        trigger = self.path.startswith(ROOT + 'imports/user/') and getattr(self, 'trigger', False)
        super().close()
        if trigger:
            self.client.ingest(self.path)


class FakeSFTP:
    def __init__(self, owner):
        self.owner, self.files, self.renames = owner, {}, 0
        self.fail_commit = self.corrupt = False
    def open(self, path, mode):
        if 'x' in mode and path in self.files:
            raise OSError('exists')
        if 'r' in mode and self.corrupt:
            return io.BytesIO(b'corrupted')
        file = FakeFile(self, path, 'w' in mode)
        file.trigger = mode == 'r+'
        return file
    def rename(self, source, destination):
        self.renames += 1
        if self.fail_commit:
            raise TimeoutError('lost acknowledgement')
        data = self.files.pop(source)
        self.files[destination] = data
    def ingest(self, path):
        info = inspect_clone(self.files[path])
        self.owner.rows.append({'cid_': 21, 'ccid': -23, 'type': 11, 'ownr': 1,
                                'cluid': info['uuid'], 'name': info['name']})
    def stat(self, path):
        if path not in self.files:
            raise FileNotFoundError(path)
        return None
    def lstat(self, path):
        return self.stat(path)
    def normalize(self, path):
        return path
    def close(self):
        pass


class FakeCompanion(Companion):
    def __init__(self, directory):
        self.rows = [{'cid_': 10, 'ccid': -23, 'type': 11, 'ownr': 1, 'cluid': str(uuid.uuid4()), 'name': 'Existing'}]
        self.rows += [{'cid_': -23, 'ccid': -14, 'type': 1002, 'ownr': 1, 'name': 'Amp'}]
        self.irs = []
        self.mutation_calls = 0
        self.lose_mutation_reply = False
        self.sftp = FakeSFTP(self)
        super().__init__('device.invalid', 2001, '/unused', directory, 'b' * 64,
                         access=lambda host, pin: (self.sftp, self.sftp))
    def library(self, expected=None, mutation=None):
        if expected is not None and expected != DEVICE:
            raise TransferError('Different Stadium')
        changed = None
        if mutation and 'op' in mutation:
            if mutation['op'] == 'export':
                row = next(r for r in self.rows if r.get('cid_') == mutation['id'])
                self.sftp.files[ROOT+'exports/'+row['cluid']+'.clone'] = archive(name=row['name'], clone_id=row['cluid'])
            else:
                self.mutation_calls += 1
                if mutation['op'] == 'delete':
                    self.rows = [r for r in self.rows if r['cid_'] != mutation['id']]
                    changed = {'removed': mutation['id']}
                elif mutation['op'] == 'move':
                    row = next(r for r in self.rows if r['cid_'] == mutation['id'])
                    row['ccid'] = mutation['destination']
                    row['posi'] = 0
                    changed = row
                elif mutation['op'] == 'mkdir':
                    changed = {'cid_': 22, 'ccid': mutation['parent'], 'type': 1002, 'ownr': 1, 'name': mutation['name']}
                    self.rows.append(changed)
                if self.lose_mutation_reply:
                    raise TransferError('Lost response after write')
        return {'deviceID': DEVICE, 'entries': [dict(row) for row in self.rows], 'changed': changed, 'irEntries': list(self.irs)}


class ArchiveTests(unittest.TestCase):
    def test_valid_archive_identity_and_hash(self):
        data = archive()
        self.assertEqual(inspect_clone(data)['name'], 'Example clone')
        self.assertEqual(len(inspect_clone(data)['sha256']), 64)
    def test_metadata_checksum_failure(self):
        with self.assertRaises(TransferError):
            inspect_clone(archive(corrupt=True))
    def test_traversal_and_absolute_paths_rejected(self):
        for path in ['../outside', '/absolute', 'output/../../outside']:
            with self.subTest(path=path), self.assertRaises(TransferError):
                inspect_clone(archive(extra=[(path, b'data')]))
    def test_duplicate_members_rejected(self):
        with self.assertRaises(TransferError):
            inspect_clone(archive(extra=[('manifest.json', b'[]')]))
    def test_bad_header_and_truncated_file(self):
        for value in [b'', b'x'*50, archive()[:-12]]:
            with self.assertRaises(TransferError):
                inspect_clone(value)
    def test_opaque_model_data_is_preserved_without_decryption(self):
        self.assertEqual(inspect_clone(archive(extra=[('output/data/opaque.bin', b'\xff\x00secretless-test')]))['name'], 'Example clone')


class TransactionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.c = FakeCompanion(Path(self.temp.name))
    def tearDown(self):
        self.temp.cleanup()
    def test_rename_does_not_trigger_native_ingestion(self):
        self.c.sftp.files['staged'] = archive()
        self.c.sftp.rename('staged', ROOT + 'imports/user/test.clone')
        self.assertEqual(len(self.c.rows), 2)
        with self.c.sftp.open(ROOT + 'imports/user/test.clone', 'r+'):
            pass
        self.assertEqual(len(self.c.rows), 3)

    def test_success_is_independently_read_back(self):
        before = dict(self.c.rows[0])
        result = self.c.import_clone(str(uuid.uuid4()), archive(), DEVICE)
        self.assertTrue(result['confirmed'])
        self.assertEqual(self.c.sftp.renames, 1)
        self.assertEqual(self.c.rows[0], before)
    def test_uncertain_commit_is_never_replayed(self):
        self.c.sftp.fail_commit = True
        job, data = str(uuid.uuid4()), archive()
        first = self.c.import_clone(job, data, DEVICE)
        self.assertEqual(first['phase'], 'uncertain')
        self.assertEqual(self.c.import_clone(job, data, DEVICE), first)
        self.assertEqual(self.c.sftp.renames, 1)
    def test_same_job_with_different_file_is_rejected(self):
        job = str(uuid.uuid4())
        self.c.import_clone(job, archive(), DEVICE)
        with self.assertRaises(TransferError):
            self.c.import_clone(job, archive(name='Other'), DEVICE)
    def test_duplicate_clone_identity_is_not_overwritten(self):
        with self.assertRaises(TransferError):
            self.c.import_clone(str(uuid.uuid4()), archive(clone_id=self.c.rows[0]['cluid']), DEVICE)
        self.assertEqual(self.c.sftp.files, {})
    def test_staged_hash_failure_does_not_commit(self):
        self.c.sftp.corrupt = True
        result = self.c.import_clone(str(uuid.uuid4()), archive(), DEVICE)
        self.assertEqual(result['phase'], 'failed')
        self.assertEqual(self.c.sftp.renames, 0)
    def test_wrong_stadium_and_job_traversal_fail_before_write(self):
        for job, device in [(str(uuid.uuid4()), 'c'*64), ('../outside', DEVICE)]:
            with self.assertRaises(TransferError):
                self.c.import_clone(job, archive(), device)
        self.assertEqual(self.c.sftp.files, {})

    def test_unindexed_physical_clone_identity_is_never_overwritten(self):
        data = archive()
        clone_id = inspect_clone(data)['uuid']
        self.c.sftp.files[ROOT + 'clones/user/' + clone_id] = b'existing unplaced clone'
        result = self.c.import_clone(str(uuid.uuid4()), data, DEVICE)
        self.assertEqual(result['phase'], 'failed')
        self.assertEqual(self.c.sftp.renames, 0)
        self.assertEqual(len(self.c.sftp.files), 1)

    def test_import_into_custom_folder_preserves_clone_identity(self):
        self.c.rows.append({'cid_': 30, 'ccid': -23, 'type': 1002, 'ownr': 1, 'name': 'Folder'})
        data = archive()
        info = inspect_clone(data)
        result = self.c.import_clone(str(uuid.uuid4()), data, DEVICE, 30)
        self.assertTrue(result['confirmed'])
        self.assertEqual(result['entry']['ccid'], 30)
        self.assertEqual(result['entry']['cluid'], info['uuid'])

    def test_cross_category_import_fails_before_upload(self):
        self.c.rows.append({'cid_': 30, 'ccid': -22, 'type': 1002, 'ownr': 1, 'name': 'Wrong category'})
        with self.assertRaises(TransferError):
            self.c.import_clone(str(uuid.uuid4()), archive(), DEVICE, 30)
        self.assertEqual(self.c.sftp.files, {})

    def test_bulk_backup_contains_original_clone_and_ir_bytes(self):
        path = '/data/stadium-family-fw/ir/Example.wav'
        wave = b'RIFF' + (8).to_bytes(4, 'little') + b'WAVE' + b'synthetic-audio'
        self.c.irs = [{'cid_': 40, 'type': 8, 'ownr': 1, 'name': 'Example IR', 'path': path}]
        self.c.sftp.files[path] = wave
        data, clones, irs = self.c.backup_library(DEVICE)
        self.assertEqual((clones, irs), (1, 1))
        with zipfile.ZipFile(io.BytesIO(data)) as bundle:
            manifest = json.loads(bundle.read('Library.json'))
            item = manifest['irs'][0]
            self.assertEqual(bundle.read(item['file']), wave)
            self.assertEqual(item['sha256'], hashlib.sha256(wave).hexdigest())
            self.assertEqual(inspect_clone(bundle.read(manifest['clones'][0]['file']))['uuid'], self.c.rows[0]['cluid'])
        self.assertEqual(self.c.sftp.renames, 0)
        self.assertEqual(self.c.mutation_calls, 0)

    def test_bulk_backup_rejects_non_ir_file_paths(self):
        self.c.irs = [{'cid_': 40, 'type': 8, 'ownr': 1, 'name': 'Unsafe', 'path': '/etc/not-an-ir.wav'}]
        with self.assertRaises(TransferError):
            self.c.backup_library(DEVICE)

    def test_protected_content_is_not_exported(self):
        self.c.rows[0]['pric'] = 1
        with self.assertRaises(TransferError):
            self.c.backup_library(DEVICE)
        self.assertEqual(self.c.sftp.files, {})

    def test_delete_retains_export_before_native_mutation(self):
        row = dict(self.c.rows[0])
        job = str(uuid.uuid4())
        result = self.c.change_library(job, {'op': 'delete', 'id': row['cid_'], 'parent': -23, 'uuid': row['cluid'], 'expectedName': row['name']}, DEVICE)
        self.assertTrue(result['confirmed'])
        backup = (self.c.jobs / (job + '-backup.clone')).read_bytes()
        self.assertEqual(inspect_clone(backup)['uuid'], row['cluid'])
        self.assertEqual(self.c.mutation_calls, 1)

    def test_uncertain_folder_creation_is_not_retried(self):
        self.c.lose_mutation_reply = True
        job = str(uuid.uuid4())
        request = {'op': 'mkdir', 'parent': -23, 'name': 'New folder'}
        result = self.c.change_library(job, request, DEVICE)
        self.assertEqual(result['phase'], 'uncertain')
        self.assertEqual(self.c.change_library(job, request, DEVICE), result)
        self.assertEqual(self.c.mutation_calls, 1)

    def test_builtin_folders_and_stale_names_are_rejected(self):
        for request in [{'op': 'delete', 'id': -23, 'parent': -14, 'expectedName': 'Amp'},
                        {'op': 'rename', 'id': 10, 'parent': -23, 'expectedName': 'Changed elsewhere', 'name': 'New'}]:
            with self.assertRaises(TransferError):
                self.c.change_library(str(uuid.uuid4()), request, DEVICE)
        self.assertEqual(self.c.mutation_calls, 0)


class HTTPTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.c = FakeCompanion(Path(self.temp.name))
        self.client = TestClient(TestServer(app_for(self.c)))
        await self.client.start_server()
    async def asyncTearDown(self):
        await self.client.close()
        self.temp.cleanup()
    async def test_authentication_and_browser_rejection(self):
        self.assertEqual((await self.client.get('/v1/status')).status, 401)
        response = await self.client.get('/v1/status', headers={'Authorization': 'Bearer '+self.c.token, 'Origin': 'https://example.invalid'})
        self.assertEqual(response.status, 403)
    async def test_identity_is_required_even_with_pairing(self):
        response = await self.client.get('/v1/status', headers={'Authorization': 'Bearer '+self.c.token})
        self.assertEqual(response.status, 409)
    async def test_authenticated_status_checks_connected_stadium(self):
        headers = {'Authorization': 'Bearer '+self.c.token, 'X-Stadium-ID': DEVICE}
        response = await self.client.get('/v1/status', headers=headers)
        self.assertEqual(response.status, 200)
        self.assertEqual((await response.json())['deviceID'], DEVICE)
        response = await self.client.get('/v1/status', headers=dict(headers, **{'X-Stadium-ID': 'b'*64}))
        self.assertEqual(response.status, 409)


if __name__ == '__main__':
    unittest.main()
