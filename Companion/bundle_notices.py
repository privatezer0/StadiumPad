"""Retain runtime/build notices in the distributable, outside the source checkout."""
import importlib.metadata
import shutil
import sys
import sysconfig
from pathlib import Path

output = Path(sys.argv[1])
output.mkdir(parents=True, exist_ok=True)
python_license = Path(sysconfig.get_path('stdlib')) / 'LICENSE.txt'
if not python_license.is_file():
    raise SystemExit('CPython LICENSE.txt is required for companion packaging.')
shutil.copy2(python_license, output / 'CPython-LICENSE.txt')
for package in ['aiohttp', 'paramiko', 'cryptography', 'cffi', 'pycparser', 'bcrypt',
                'pynacl', 'invoke', 'yarl', 'multidict', 'frozenlist', 'aiosignal',
                'propcache', 'attrs', 'idna', 'aiohappyeyeballs', 'pyinstaller']:
    try:
        distribution = importlib.metadata.distribution(package)
    except importlib.metadata.PackageNotFoundError:
        continue
    for item in distribution.files or []:
        if any(word in item.name.upper() for word in ['LICENSE', 'COPYING', 'NOTICE']):
            source = distribution.locate_file(item)
            if source.is_file():
                target = output / package / Path(str(item))
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
root = Path(__file__).resolve().parents[1]
for name, source in [('StadiumPad-LICENSE.txt', root / 'LICENSE'),
                     ('Upstream-MIT-LICENSE.txt', root / 'docs/REFERENCE_LICENSE.txt'),
                     ('THIRD_PARTY.md', root / 'docs/THIRD_PARTY.md')]:
    shutil.copy2(source, output / name)
