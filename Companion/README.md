# StadiumPad Companion

Optional macOS14+ helper for clone file transfers and User library backups. Preset
editing and library browsing connect straight from the tablet to Stadium; this Mac
is only needed for file operations. Supports the installed official Helix Stadium
editor1.4.0.20 arm64 image. Unknown builds fail closed. No Xcode/Python installation
is required to run a packaged app; developers need them to build it.

Open the app, choose Stadium, connect, verify its SSH fingerprint and allow Local
Network access. Scan the QR on your own tablet or paste Copy Pairing Link into
StadiumPad's Librarian pairing dialog. Keep the Mac app open. Pairing links grant
file access; treat them as private. Do not share screenshots of the QR publicly.

Clone import/export, new User folders, rename/delete and Download Library are
supported. Download Library stores a ZIP with original User .clone files, User IR
WAVs and a metadata/checksum manifest on the tablet. Factory/protected content is
excluded. Transfers use local HTTPS with certificate pinning and token authentication;
SFTP authentication is prepared in RAM from the user's own verified installed
editor. No vendor key is bundled or persisted or sent to the tablet. SSH identity is
verified first. No cloud service is involved.

Imports refuse occupied UUIDs, including unindexed files, and use exclusive staging,
byte verification and a unique atomic ingest rename followed by a non-truncating close-write notification. Uncertain jobs are recorded
and never replayed. Rename/delete keeps an export on the Mac first. Current limits:
8 MB/file, 50 import selections, 256 MB backup, 2048 clone-tree entries, eight folder
levels. Backups must finish against an unchanged library. IR upload/assignment,
clone-to-block assignment and protected/premium content export are not implemented.

## Build

Use an external build folder and Python3.13 virtual environment:

```sh
python3 -m venv /external/StadiumPadCompanionVenv
/external/StadiumPadCompanionVenv/bin/pip install -r Companion/requirements.txt pyinstaller==6.22.3
export STADIUMPAD_COMPANION_BUILD=/external/StadiumPadCompanionBuild
export STADIUMPAD_COMPANION_PYTHON=/external/StadiumPadCompanionVenv/bin/python
export STADIUMPAD_COMPANION_SIGNING_IDENTITY='your Apple-issued signing identity'
bash Companion/build.sh
```

The build includes Swift stadium-library plus a Python service and retained package
licenses. Use an Apple-issued identity and a unique helper executable UUID for
reliable macOS Local Network permission tracking. The owner development build is
signed but not notarized: general distribution still needs Developer ID signing,
notarization and public installer qualification. Never ask users to disable security
protections. MIT upstream research credit is in ACKNOWLEDGMENTS.md and
../docs/THIRD_PARTY.md.

Private pairing/certificate state and transfer journals live in Application Support/
StadiumPad Companion. Never commit that directory, user clone/IR files or extracted
editor identities. Synthetic tests: `python -m unittest discover -s Companion/Tests`.
