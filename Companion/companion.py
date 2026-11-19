"""StadiumPad's authenticated, TLS-only, single-Stadium clone file companion."""
import argparse
import asyncio
import datetime
import gzip
import hashlib
import hmac
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import ssl
import subprocess
import tarfile
import time
import uuid
import zlib
import zipfile

from aiohttp import web
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

import editor_access

MAX_FILE = 8 * 1024 * 1024
MAX_ARCHIVE = 16 * 1024 * 1024
ROOT = '/data/stadium-family-fw/proxy/'
CATEGORIES = {'amp_cab': -22, 'amp': -23, 'preamp': -24, 'distortion': -25}


class TransferError(Exception):
    pass


def inspect_clone(data):
    """Inspect only public archive metadata; never extract or decrypt model data."""
    if not 24 < len(data) <= MAX_FILE or data[:24] != bytes.fromhex('47474759000000004e4f4c43000000000001000000000000'):
        raise TransferError('Choose a supported .clone file exported by Helix Stadium.')
    try:
        with gzip.GzipFile(fileobj=io.BytesIO(data[24:])) as compressed:
            body = compressed.read(MAX_ARCHIVE + 1)
        if len(body) > MAX_ARCHIVE:
            raise TransferError('The clone archive is too large.')
        metadata = None
        manifest = None
        names = set()
        with tarfile.open(fileobj=io.BytesIO(body), mode='r:') as archive:
            for index, member in enumerate(archive):
                path = PurePosixPath(member.name)
                name = str(path)
                if index > 96 or path.is_absolute() or '..' in path.parts or member.issym() or member.islnk() or name in names:
                    raise TransferError('Unsafe or duplicate paths in clone archive.')
                names.add(name)
                if not member.isdir() and not member.isfile():
                    raise TransferError('Unsupported clone archive member.')
                if member.size < 0 or member.size > MAX_FILE:
                    raise TransferError('The clone archive contains an oversized member.')
                if name in ('manifest.json', 'output/data/stadium-database-metadata.json'):
                    if member.size > 128 * 1024:
                        raise TransferError('Clone metadata is too large.')
                    raw = archive.extractfile(member).read()
                    if name == 'manifest.json':
                        manifest = json.loads(raw)
                    else:
                        metadata = json.loads(raw)
                        metadata_raw = raw
        if not isinstance(metadata, dict) or not isinstance(manifest, list):
            raise TransferError('Clone metadata is missing.')
        matches = [m for m in manifest if m.get('path') == 'output/data/stadium-database-metadata.json']
        if len(matches) != 1 or matches[0].get('encrypted') or matches[0].get('size') != len(metadata_raw) or matches[0].get('checksum') != zlib.crc32(metadata_raw):
            raise TransferError('Clone metadata checksum does not match.')
        clone_id = str(uuid.UUID(metadata['clone_uuid']))
        category = metadata['clone_category']
        name = metadata['clone_name']
        if clone_id != metadata['clone_uuid'] or category not in CATEGORIES or not isinstance(name, str) or not name.strip() or len(name) > 128:
            raise TransferError('Invalid clone identity, name or category.')
        return {'uuid': clone_id, 'name': name, 'category': category, 'container': CATEGORIES[category],
                'sha256': hashlib.sha256(data).hexdigest()}
    except TransferError:
        raise
    except (ValueError, KeyError, TypeError, OSError, tarfile.TarError, EOFError, AttributeError):
        raise TransferError('The clone archive is damaged or unsupported.') from None


def require_user_export(row):
    if row.get('ownr') != 1 or any(row.get(field, 0) for field in ('pric', 'locked', 'lckd', 'lock')):
        raise TransferError('Locked, premium or Factory content cannot be copied by this companion.')


def private_json(path, value):
    temporary = path.with_suffix('.new')
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as out:
        json.dump(value, out)
        out.flush()
        os.fsync(out.fileno())
    os.replace(temporary, path)


class Companion:
    def __init__(self, host, port, agent, directory, trusted_ssh, access=editor_access.connect):
        self.host, self.port, self.agent = host, port, agent
        self.directory = Path(directory)
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(self.directory, 0o700)
        self.trusted_ssh = trusted_ssh
        self.access = access
        self.lock = asyncio.Lock()
        identity_path = self.directory / 'pairing.json'
        if identity_path.exists():
            self.token = json.loads(identity_path.read_text())['token']
        else:
            self.token = secrets.token_urlsafe(32)
            private_json(identity_path, {'token': self.token})
        self.jobs = self.directory / 'Jobs'
        self.jobs.mkdir(mode=0o700, exist_ok=True)

    def library(self, expected=None, mutation=None):
        request = {'host': self.host, 'port': self.port}
        if expected:
            request['deviceID'] = expected
        if mutation:
            request.update(mutation)
        result = subprocess.run([str(self.agent)], input=json.dumps(request).encode(), capture_output=True, timeout=30)
        try:
            value = json.loads(result.stdout)
        except (ValueError, UnicodeDecodeError):
            raise TransferError('The Stadium library could not be read.') from None
        if result.returncode or value.get('error'):
            raise TransferError(value.get('error', 'The Stadium library could not be read.'))
        return value

    def job_path(self, job):
        try:
            if str(uuid.UUID(job)) != job:
                raise ValueError()
        except (ValueError, TypeError, AttributeError):
            raise TransferError('Invalid transfer identity.') from None
        return self.jobs / (job + '.json')

    @staticmethod
    def require_unused_identity(client, clone_id):
        # Unplaced/deployed clones may not appear in the User library index.
        paths = [ROOT + 'clones/user/' + clone_id, ROOT + 'clones/factory/' + clone_id,
                 ROOT + 'deployed/' + clone_id.replace('-', '') + '.bin']
        for path in paths:
            try:
                client.lstat(path)
            except FileNotFoundError:
                continue
            raise TransferError('This clone identity already has files on Stadium, even if it is not listed. No overwrite was attempted; review it in the desktop editor.')

    def import_clone(self, job, data, expected, destination=None):
        path = self.job_path(job)
        info = inspect_clone(data)
        if destination is not None and (type(destination) is not int or destination == 0):
            raise TransferError('Invalid clone destination folder.')
        target = destination if destination and destination > 0 else info['container']
        if path.exists():
            previous = json.loads(path.read_text())
            if previous.get('sha256') != info['sha256'] or previous.get('deviceID') != expected or previous.get('destination') != target:
                raise TransferError('This transfer identity belongs to a different file or Stadium.')
            return previous  # Never replay an uncertain write.
        before = self.library(expected)
        rows = before['entries']
        if target > 0:
            by_id = {r['cid_']: r for r in rows}
            parent = target
            visited = set()
            while parent > 0 and parent not in visited and len(visited) < 8:
                visited.add(parent)
                folder = by_id.get(parent, {})
                if folder.get('type') != 1002 or folder.get('ownr') != 1:
                    raise TransferError('Choose a User clone folder.')
                parent = folder.get('ccid', 0)
            if parent != info['container']:
                raise TransferError('This clone belongs to a different category. Choose a folder in its own category.')
        if any(r.get('cluid') == info['uuid'] for r in rows):
            raise TransferError('This clone is already on the Stadium. Existing clones are never overwritten.')
        if any(r.get('name', '').casefold() == info['name'].casefold() and r.get('ccid') in (info['container'], target) for r in rows):
            raise TransferError('A clone with this name is already in that category. Nothing was uploaded.')
        state = dict(info, job=job, deviceID=expected, phase='preparing', confirmed=False,
                     started=time.time(), destination=target, message='Preparing clone import')
        private_json(path, state)
        private_json(self.jobs / (job + '-before.json'), before)
        source = self.jobs / (job + '.clone')
        with open(os.open(source, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as out:
            out.write(data)
        remote_stage = ROOT + 'imports/.tmp/stadiumpad-' + job + '.part'
        remote_commit = ROOT + 'imports/user/stadiumpad-' + job + '.clone'
        transport = client = None
        committed = False
        try:
            transport, client = self.access(self.host, self.trusted_ssh)
            self.require_unused_identity(client, info['uuid'])
            # Revalidate device/library immediately before the first file write.
            fresh = self.library(expected)
            if fresh['entries'] != rows:
                raise TransferError('The library changed. Refresh before importing.')
            state.update(phase='uploading', message='Uploading clone to Stadium')
            private_json(path, state)
            with client.open(remote_stage, 'wx') as out:
                for offset in range(0, len(data), 32768):
                    out.write(data[offset:offset + 32768])
                    state['bytes'] = min(len(data), offset + 32768)
                    state['total'] = len(data)
                    private_json(path, state)
            with client.open(remote_stage, 'rb') as check:
                uploaded = check.read(MAX_FILE + 1)
            if hashlib.sha256(uploaded).hexdigest() != info['sha256']:
                raise TransferError('The staged file did not match. It was not submitted for import.')
            self.require_unused_identity(client, info['uuid'])
            if self.library(expected)['entries'] != rows:
                raise TransferError('The library changed before submission. Nothing was imported.')
            state.update(phase='committing', message='Waiting for Stadium import confirmation')
            private_json(path, state)
            committed = True  # Journal BEFORE rename: a lost reply is uncertain, never retry.
            client.rename(remote_stage, remote_commit)
            # The native watcher ingests on close-write, not an atomic move event.
            # Reopen the verified task-owned file without truncating or rewriting it.
            # This is part of one journaled submission, never a job retry.
            with client.open(remote_commit, 'r+'):
                pass
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                after = self.library(expected)
                found = [r for r in after['entries'] if r.get('type') == 11 and r.get('cluid') == info['uuid']]
                if len(found) == 1:
                    if found[0].get('name') != info['name'] or found[0].get('ccid') != info['container']:
                        raise TransferError('The imported clone identity did not match its native category.')
                    if target != info['container']:
                        state.update(phase='placing', message='Placing imported clone in the selected folder')
                        private_json(path, state)
                        after = self.library(expected, {'op': 'move', 'id': found[0]['cid_'], 'uuid': info['uuid'], 'parent': info['container'], 'expectedName': info['name'], 'destination': target})
                        found = [r for r in after['entries'] if r.get('type') == 11 and r.get('cluid') == info['uuid']]
                        if len(found) != 1 or found[0].get('ccid') != target:
                            raise TransferError('Clone placement was not confirmed. Refresh before trying again.')
                    original = {r['cid_']: r for r in rows}
                    current = {r['cid_']: r for r in after['entries']}
                    if any(current.get(k) != v for k, v in original.items()):
                        raise TransferError('The clone appeared, but other library changes were observed. Check the library before continuing.')
                    if found[0].get('name') != info['name'] or found[0].get('ccid') != target:
                        raise TransferError('The imported clone identity did not match the requested name/folder.')
                    state.update(phase='complete', confirmed=True, entry=found[0], message='Clone imported and verified')
                    private_json(path, state)
                    return state
                time.sleep(.35)
            raise TransferError('Import was submitted but not confirmed. Refresh the library; do not blindly retry.')
        except Exception as error:
            state.update(phase='uncertain' if committed else 'failed',
                         message=str(error) if isinstance(error, TransferError) else 'File transfer failed. Check the Stadium and refresh before retrying.')
            private_json(path, state)
            return state
        finally:
            if client:
                client.close()
            if transport:
                transport.close()

    def export_clone(self, content_id, clone_id, expected):
        before = self.library(expected)
        matching = [r for r in before['entries'] if r.get('cid_') == content_id and r.get('cluid') == clone_id and r.get('type') == 11]
        if len(matching) != 1 or str(uuid.UUID(clone_id)) != clone_id:
            raise TransferError('The selected clone changed. Refresh the library.')
        require_user_export(matching[0])
        self.library(expected, {'op': 'export', 'id': content_id, 'uuid': clone_id, 'expectedName': matching[0]['name']})
        transport, client = self.access(self.host, self.trusted_ssh)
        try:
            with client.open(ROOT + 'exports/' + clone_id + '.clone', 'rb') as source:
                data = source.read(MAX_FILE + 1)
        finally:
            client.close()
            transport.close()
        info = inspect_clone(data)
        if info['uuid'] != clone_id:
            raise TransferError('The exported clone identity did not match.')
        after = self.library(expected)
        if matching[0] not in after['entries']:
            raise TransferError('The selected clone changed during export. Nothing was delivered.')
        return data

    def backup_library(self, expected):
        before = self.library(expected, {'includeIRs': True})
        entries = [r for r in before['entries'] if r.get('type') == 11 and r.get('ownr') == 1]
        irs = before.get('irEntries', [])
        for row in entries + irs:
            require_user_export(row)
        manifest = {'format': 'StadiumPad Library Backup 1', 'deviceID': expected, 'created': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'clones': [], 'irs': []}
        total = 0
        output = io.BytesIO()
        transport, client = self.access(self.host, self.trusted_ssh)
        def add(archive, folder, row, data, extension):
            nonlocal total
            total += len(data)
            if len(data) > MAX_FILE or total > 256 * 1024 * 1024:
                raise TransferError('The library exceeds this version’s 256 MB backup limit.')
            safe = re.sub(r'[^\w .()-]', '_', row.get('name', 'Untitled'))[:100]
            filename = folder + '/' + str(row['cid_']) + '-' + safe + extension
            archive.writestr(filename, data)
            item = dict(row, file=filename, sha256=hashlib.sha256(data).hexdigest(), size=len(data))
            manifest['clones' if folder == 'Clones' else 'irs'].append(item)
        try:
            with zipfile.ZipFile(output, mode='w', compression=zipfile.ZIP_STORED) as archive:
                for row in entries:
                    clone_id = row.get('cluid', '')
                    try:
                        if str(uuid.UUID(clone_id)) != clone_id:
                            raise ValueError()
                    except (ValueError, TypeError, AttributeError):
                        raise TransferError('A User clone has no valid archive identity. Inspect it in the desktop editor before backing up.') from None
                    path = ROOT + 'exports/' + clone_id + '.clone'
                    try:
                        client.stat(path)
                    except FileNotFoundError:
                        self.library(expected, {'op': 'export', 'id': row['cid_'], 'uuid': clone_id, 'expectedName': row['name']})
                    with client.open(path, 'rb') as source:
                        data = source.read(MAX_FILE + 1)
                    if inspect_clone(data)['uuid'] != clone_id:
                        raise TransferError('A clone archive did not match its library identity.')
                    add(archive, 'Clones', row, data, '.clone')
                for row in irs:
                    path = row.get('path', '')
                    relative = PurePosixPath(path)
                    if not path.startswith('/data/stadium-family-fw/ir/') or '..' in relative.parts or not path.lower().endswith('.wav'):
                        raise TransferError('An IR points outside the supported User IR file library.')
                    normalized = client.normalize(path)
                    if not normalized.startswith('/data/stadium-family-fw/ir/'):
                        raise TransferError('An IR file resolves outside the User IR library.')
                    with client.open(normalized, 'rb') as source:
                        data = source.read(MAX_FILE + 1)
                    if len(data) < 12 or data[:4] not in (b'RIFF', b'RF64') or data[8:12] != b'WAVE':
                        raise TransferError('An IR is not an ordinary WAV file. No partial backup was delivered.')
                    add(archive, 'IRs', row, data, '.wav')
                after = self.library(expected, {'includeIRs': True})
                if before['entries'] != after['entries'] or irs != after.get('irEntries', []):
                    raise TransferError('The library changed during backup. No incomplete snapshot was delivered; download it again when changes are finished.')
                archive.writestr('Library.json', json.dumps(manifest, indent=2, ensure_ascii=False).encode())
        finally:
            client.close()
            transport.close()
        return output.getvalue(), len(entries), len(irs)

    def change_library(self, job, request, expected):
        path = self.job_path(job)
        allowed = {'op', 'parent', 'id', 'uuid', 'expectedName', 'name'}
        if not isinstance(request, dict) or set(request) - allowed or request.get('op') not in ('mkdir', 'rename', 'delete'):
            raise TransferError('Unsupported clone library action.')
        digest = hashlib.sha256(json.dumps(request, sort_keys=True).encode()).hexdigest()
        if path.exists():
            previous = json.loads(path.read_text())
            if previous.get('requestHash') != digest or previous.get('deviceID') != expected:
                raise TransferError('This operation identity has already been used.')
            return previous
        before = self.library(expected)
        parent = request.get('parent')
        if not type(parent) is int or not any(r.get('cid_') == parent and r.get('type') == 1002 for r in before['entries']):
            raise TransferError('Choose a folder inside User Clones.')
        selected = None
        if request['op'] != 'mkdir':
            matches = [r for r in before['entries'] if r.get('cid_') == request.get('id') and r.get('ccid') == parent and r.get('name') == request.get('expectedName') and r.get('ownr') == 1]
            if len(matches) != 1 or request['id'] <= 0:
                raise TransferError('The selected clone or custom folder changed.')
            selected = matches[0]
            if selected.get('type') == 11 and selected.get('cluid') != request.get('uuid'):
                raise TransferError('The selected clone identity changed.')
            if selected.get('type') not in (11, 1002):
                raise TransferError('Only User clones and custom clone folders can be changed.')
        state = {'job': job, 'deviceID': expected, 'requestHash': digest, 'phase': 'preparing', 'confirmed': False, 'message': 'Preparing clone library operation'}
        private_json(path, state)
        private_json(self.jobs / (job + '-before.json'), before)
        try:
            if selected and selected['type'] == 11:
                backup = self.export_clone(selected['cid_'], selected['cluid'], expected)
                with open(os.open(self.jobs / (job + '-backup.clone'), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as out:
                    out.write(backup)
            state.update(phase='committing', message='Waiting for Stadium library confirmation')
            private_json(path, state)
            result = self.library(expected, request)
            current = {r['cid_']: r for r in result['entries']}
            changed_id = request.get('id')
            for original in before['entries']:
                if original['cid_'] == changed_id:
                    continue
                actual = current.get(original['cid_'])
                old = dict(original)
                if request['op'] == 'delete' and original.get('ccid') == parent:
                    old.pop('posi', None)
                    actual = dict(actual) if actual else None
                    if actual:
                        actual.pop('posi', None)
                if actual != old:
                    raise TransferError('Other library records changed during the operation. Refresh before continuing.')
            state.update(phase='complete', confirmed=True, entry=result.get('changed'), message='Clone library change verified')
            private_json(path, state)
        except Exception as error:
            state.update(phase='uncertain' if state['phase'] == 'committing' else 'failed', message=str(error) if isinstance(error, TransferError) else 'The library operation was not confirmed. Refresh before trying again.')
            private_json(path, state)
        return state


def app_for(companion):
    @web.middleware
    async def authenticate(request, handler):
        value = request.headers.get('Authorization', '')
        if not hmac.compare_digest(value, 'Bearer ' + companion.token):
            raise web.HTTPUnauthorized(text='Pair this tablet with the Mac companion first.')
        if request.headers.get('Origin'):
            raise web.HTTPForbidden(text='Browser requests are not supported.')
        try:
            return await handler(request)
        except web.HTTPException:
            raise
        except TransferError as error:
            return web.json_response({'error': str(error)}, status=409)
        except (ValueError, KeyError, TypeError):
            return web.json_response({'error': 'Invalid clone request.'}, status=400)
        except Exception:
            return web.json_response({'error': 'The companion could not complete the request. No success was confirmed.'}, status=503)

    app = web.Application(client_max_size=MAX_FILE, middlewares=[authenticate])
    def expected(request):
        value = request.headers.get('X-Stadium-ID', '')
        if not re.fullmatch('[0-9a-f]{64}', value):
            raise TransferError('Connect the tablet to its Stadium before transferring files.')
        return value
    async def status(request):
        result = await asyncio.to_thread(companion.library, expected(request))
        return web.json_response({'deviceID': result['deviceID'], 'ready': True})
    async def import_file(request):
        identity = expected(request)
        job = request.match_info['job']
        companion.job_path(job)
        data = await asyncio.wait_for(request.read(), timeout=30)
        folder = request.headers.get('X-Clone-Folder')
        destination = int(folder) if folder is not None else None
        async with companion.lock:
            result = await asyncio.to_thread(companion.import_clone, job, data, identity, destination)
        return web.json_response(result, status=200 if result.get('confirmed') else 409)
    async def manage(request):
        identity = expected(request)
        job = request.match_info['job']
        companion.job_path(job)
        data = await asyncio.wait_for(request.read(), timeout=10)
        if len(data) > 4096:
            raise TransferError('Library request is too large.')
        operation = json.loads(data)
        async with companion.lock:
            result = await asyncio.to_thread(companion.change_library, job, operation, identity)
        return web.json_response(result, status=200 if result.get('confirmed') else 409)
    async def job(request):
        path = companion.job_path(request.match_info['job'])
        if not path.exists():
            raise web.HTTPNotFound()
        value = json.loads(path.read_text())
        if value['deviceID'] != expected(request):
            raise TransferError('This transfer belongs to another Stadium.')
        return web.json_response(value)
    async def backup(request):
        async with companion.lock:
            data, clones, irs = await asyncio.to_thread(companion.backup_library, expected(request))
        return web.Response(body=data, content_type='application/zip', headers={'X-Content-SHA256': hashlib.sha256(data).hexdigest(), 'X-Clone-Count': str(clones), 'X-IR-Count': str(irs)})
    async def export(request):
        async with companion.lock:
            data = await asyncio.to_thread(companion.export_clone, int(request.match_info['cid']), request.match_info['uuid'], expected(request))
        return web.Response(body=data, content_type='application/octet-stream', headers={'X-Content-SHA256': hashlib.sha256(data).hexdigest()})
    app.router.add_get('/v1/status', status)
    app.router.add_get('/v1/backup/library', backup)
    app.router.add_post('/v1/import/{job}', import_file)
    app.router.add_get('/v1/jobs/{job}', job)
    app.router.add_post('/v1/manage/{job}', manage)
    app.router.add_get('/v1/export/{cid}/{uuid}', export)
    return app


def certificate(directory):
    key_file, cert_file = directory / 'tls-key.pem', directory / 'tls-cert.pem'
    if not key_file.exists() or not cert_file.exists():
        key = ec.generate_private_key(ec.SECP256R1())
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'StadiumPad Companion')])
        now = datetime.datetime.now(datetime.timezone.utc)
        cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
                .serial_number(x509.random_serial_number()).not_valid_before(now - datetime.timedelta(minutes=5))
                .not_valid_after(now + datetime.timedelta(days=3650)).sign(key, hashes.SHA256()))
        for path, data in [(key_file, key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())),
                           (cert_file, cert.public_bytes(serialization.Encoding.PEM))]:
            with open(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'wb') as out:
                out.write(data)
    cert = x509.load_pem_x509_certificate(cert_file.read_bytes())
    pin = cert.fingerprint(hashes.SHA256()).hex()
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(str(cert_file), str(key_file))
    return context, pin


async def run(args):
    if args.probe:
        # A short-lived denied helper may not trigger macOS's permission alert
        # (Apple TN3179 / FB16131937). Keep this read-only probe alive while the
        # user responds. No transfer or uncertain write is ever retried here.
        deadline = time.monotonic() + 25
        while True:
            try:
                value = await asyncio.to_thread(editor_access.probe, args.host)
                print(json.dumps({'fingerprint': value}), flush=True)
                return
            except (OSError, RuntimeError) as error:
                if time.monotonic() >= deadline:
                    raise error
                await asyncio.sleep(1)

    if not args.trusted_ssh or not re.fullmatch('[0-9a-f]{64}', args.trusted_ssh):
        raise TransferError('Verify the Stadium file connection on the Mac first.')
    companion = Companion(args.host, args.port, Path(args.agent), Path(args.state), args.trusted_ssh)
    # Check editor compatibility and credentials before exposing a pairing link.
    def check():
        transport, client = editor_access.connect(args.host, args.trusted_ssh)
        client.close()
        transport.close()
    await asyncio.to_thread(check)
    await asyncio.to_thread(companion.library)
    context, pin = certificate(companion.directory)
    runner = web.AppRunner(app_for(companion), access_log=None, keepalive_timeout=10, max_line_size=4096, max_field_size=4096)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', args.listen, ssl_context=context, backlog=8)
    await site.start()
    port = site._server.sockets[0].getsockname()[1]
    from urllib.parse import urlencode
    link = 'stadiumpad://companion?' + urlencode({'host': args.advertise, 'port': port, 'pin': pin, 'token': companion.token})
    print(json.dumps({'ready': True, 'link': link, 'port': port}), flush=True)
    try:
        await asyncio.Event().wait()
    finally:
        await runner.cleanup()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', required=True)
    parser.add_argument('--port', type=int, default=2001)
    parser.add_argument('--agent')
    parser.add_argument('--state')
    parser.add_argument('--trusted-ssh')
    parser.add_argument('--advertise')
    parser.add_argument('--listen', type=int, default=0)
    parser.add_argument('--probe', action='store_true')
    arguments = parser.parse_args()
    try:
        asyncio.run(run(arguments))
    except KeyboardInterrupt:
        pass
    except Exception as error:
        message = ('Could not probe Stadium: ' + str(error)) if arguments.probe else 'Could not connect. Check the installed editor version, Stadium address and file-connection identity.'
        print(json.dumps({'error': message}), flush=True)
        raise SystemExit(1)
