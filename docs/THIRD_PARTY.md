# Third-party notices

Research/reference: Dwayne Charrington, Vheissu/helix-stadium-tools, MIT,
commit dad97d3a2011290f7f6630d04cc1a819cc58752b. See REFERENCE_LICENSE.txt.
Swift implementation and UI use that research; controller interpretation and
property-envelope behavior and native block-reorder planning are adapted from the reference. See ACKNOWLEDGMENTS.md.

Python msgpack (msgpack-python) is an Apache-2.0 licensed development/test dependency,
installed separately, not bundled into the Swift application. See its upstream
LICENSE and COPYING files for component notices. Swift, SwiftUI, Foundation and
Network are provided by Apple and governed by their respective terms.

Vendor trademarks identify supported devices/workflow inspiration only. No vendor
artwork, DSP code, factory preset payloads or extracted metadata is included in the
source repository. Generated local metadata remains ignored.


The optional Mac companion bundles CPython (PSF license), aiohttp (Apache-2.0),
Paramiko (LGPL-2.1-or-later), cryptography (Apache-2.0 OR BSD-3-Clause) and their
runtime dependencies through PyInstaller (GPL with its bootloader distribution
exception). Package metadata/license files are retained by the build. Exact primary
versions are pinned in Companion/requirements.txt. Source and build instructions
for this service are included in Companion/; these libraries are not embedded in
the iPad or Android app. Consult their bundled dist-info notices and upstream source:
https://github.com/aio-libs/aiohttp, https://github.com/paramiko/paramiko,
https://github.com/pyca/cryptography, https://github.com/python/cpython,
https://github.com/pyinstaller/pyinstaller. Paramiko source can be rebuilt/replaced
using the documented Python environment and companion build script.

The local supported-editor credential preparation follows former MIT upstream
commits 01c278a / b4a20e0 (removed af0b6eb). REFERENCE_LICENSE.txt applies to that
adaptation. No editor binary or extracted identity is bundled.
