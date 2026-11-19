"""Use a locally installed, verified editor for Mac-only file authentication.

No editor binary or credential is bundled. Key material is decoded in memory only
and never returned to clients, written to disk, or logged. The adaptation follows
helix-stadium-tools' former MIT credential preparation (01c278a/b4a20e0), credited
in ACKNOWLEDGMENTS.md and docs/THIRD_PARTY.md. Unknown editor builds fail closed.
"""
import hashlib
import io
import struct
import socket
from pathlib import Path

import paramiko
from cryptography.hazmat.primitives import serialization

EDITOR = Path('/Applications/Line6/Helix Stadium.app/Contents/MacOS/Helix Stadium')
EDITOR_HASH = 'fd579b070c12566552850454f087c3b059a7728c1e681791bda95d820280e640'


def arm64_image(editor):
    path = Path(editor)
    if path.stat().st_size > 200 * 1024 * 1024:
        raise RuntimeError('Unsupported editor size.')
    data = path.read_bytes()
    if len(data) < 32:
        raise RuntimeError('Unsupported editor image.')
    magic = struct.unpack_from('>I', data)[0]
    if magic in (0xcafebabe, 0xcafebabf):
        count = struct.unpack_from('>I', data, 4)[0]
        if not 0 < count <= 16:
            raise RuntimeError('Unsupported editor architecture table.')
        size = 32 if magic == 0xcafebabf else 20
        for index in range(count):
            offset = 8 + index * size
            cpu = struct.unpack_from('>I', data, offset)[0]
            if cpu == 0x0100000c:
                start, length = struct.unpack_from('>QQ' if magic == 0xcafebabf else '>II', data, offset + 8)
                if start > len(data) or length > len(data) - start:
                    raise RuntimeError('Invalid editor architecture bounds.')
                return data[start:start + length]
        raise RuntimeError('A supported editor arm64 image is required.')
    if struct.unpack_from('<I', data)[0] == 0xfeedfacf and struct.unpack_from('<I', data, 4)[0] == 0x0100000c:
        return data
    raise RuntimeError('Unsupported editor image.')


def editor_identities(editor=EDITOR):
    binary = arm64_image(editor)
    if hashlib.sha256(binary).hexdigest() != EDITOR_HASH:
        raise RuntimeError('This installed Helix Stadium editor version is not supported for file transfers.')
    segments = []
    offset = 32
    for _ in range(struct.unpack_from('<I', binary, 16)[0]):
        command, size = struct.unpack_from('<II', binary, offset)
        if command == 0x19:
            address, length, file = struct.unpack_from('<QQQ', binary, offset + 24)
            segments.append((address, length, file))
        offset += size

    def at(address):
        for base, length, file in segments:
            if base <= address < base + length:
                return file + address - base
        raise RuntimeError('Unsupported editor layout.')

    for address, size_address in [(0x101428c04, 0x101429a94), (0x101427d70, 0x101428c00)]:
        size = struct.unpack_from('<I', binary, at(size_address))[0]
        if not 0 < size < 65536:
            raise RuntimeError('Unsupported editor identity data.')
        raw = binary[at(address):at(address) + size]
        packed = []
        i = 0
        while i < len(raw):
            if len(packed) % 2:
                packed.append(((raw[i] << 4) | raw[i + 1]) & 255)
                i += 2
            else:
                packed.append(raw[i])
                i += 1
        previous = 0x65
        plain = []
        for byte in packed:
            plain.append(byte ^ previous)
            previous = byte
        parsed = serialization.load_pem_private_key(bytes(plain).rstrip(b'\0'), password=None)
        pem = parsed.private_bytes(serialization.Encoding.PEM,
                                   serialization.PrivateFormat.TraditionalOpenSSL,
                                   serialization.NoEncryption()).decode()
        for kind in (paramiko.RSAKey, paramiko.ECDSAKey, paramiko.Ed25519Key):
            try:
                yield kind.from_private_key(io.StringIO(pem))
                break
            except paramiko.SSHException:
                pass


def fingerprint(key):
    return hashlib.sha256(key.asbytes()).hexdigest()


def probe(host):
    transport = paramiko.Transport(socket.create_connection((host, 22), timeout=5))
    try:
        transport.start_client(timeout=5)
        return fingerprint(transport.get_remote_server_key())
    finally:
        transport.close()


def connect(host, trusted_fingerprint):
    for identity in editor_identities():
        transport = paramiko.Transport(socket.create_connection((host, 22), timeout=5))
        transport.banner_timeout = 5
        transport.auth_timeout = 5
        try:
            transport.start_client(timeout=5)
            if fingerprint(transport.get_remote_server_key()) != trusted_fingerprint:
                raise RuntimeError('The Stadium SSH identity changed. Reconnect and verify it on the Mac.')
            transport.auth_publickey('hedit', identity)
            if transport.is_authenticated():
                client = paramiko.SFTPClient.from_transport(transport)
                client.get_channel().settimeout(20)
                return transport, client
        except paramiko.AuthenticationException:
            pass
        except Exception:
            transport.close()
            raise
        transport.close()
    raise RuntimeError('The Stadium rejected the installed editor file-transfer identity.')
