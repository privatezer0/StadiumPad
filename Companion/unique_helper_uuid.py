"""Give our packaged helper its own build UUID before code signing.

PyInstaller reuses a bootloader. Apple TN3179 requires distinct executable UUIDs
for reliable local-network identity tracking. Only our helper's LC_UUID metadata
is changed; no vendor executable or machine privacy preference is modified.
"""
import hashlib
from pathlib import Path
import struct
import sys
import uuid

path = Path(sys.argv[1])
data = bytearray(path.read_bytes())
if struct.unpack_from('<I', data)[0] != 0xfeedfacf:
    raise SystemExit('Expected an Apple Silicon Mach-O helper.')
count = struct.unpack_from('<I', data, 16)[0]
offset = 32
found = None
for _ in range(count):
    command, size = struct.unpack_from('<II', data, offset)
    if command == 0x1b:
        found = offset + 8
        break
    offset += size
if found is None:
    raise SystemExit('The helper has no build UUID.')
data[found:found + 16] = bytes(16)
build = uuid.uuid5(uuid.NAMESPACE_DNS, 'com.privatezero.stadiumpad.companion.helper.' + hashlib.sha256(data).hexdigest())
data[found:found + 16] = build.bytes
path.write_bytes(data)
