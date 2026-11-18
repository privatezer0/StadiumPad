# StadiumPad

An unofficial, open-source **iPad/tablet editor for Line 6 Helix Stadium**.
Connect directly over your local Wi-Fi network; no Mac relay is needed while using
the app. This is an early community proof of concept, not a complete replacement
for the official desktop editor.

<p align="center"><img src="iPad/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.jpg" width="220" alt="StadiumPad metallic blue app icon"></p>

## What it does

- **Preset view:** scrolling User/Factory preset browser, expandable setlist folders,
  signal chain, named parameter controls, category/model lists, exact selected-model
  highlighting and automatic scrolling. Drag effects to rearrange occupied or empty
  positions within the same signal row. Includes Looper, FX Loop and Utility models.
- **Focus View:** tap the aperture beside the model name. Factory named tones and
  X/Y blending for mapped models, precise X/Y controls, Restore starting tone,
  cabinet mic placement, and editable EQ band gain/frequency controls. It occupies
  the signal-chain area while presets and normal controls remain visible. Opening
  the view preserves the tone; adjustments are live and remain unsaved until Save.
- **Scene view:** eight large colored scene buttons using the preset's snapshot names.
  Select an existing scene or confirm copying the current scene into an empty slot.
- **Footswitch view:** virtual Stomp A/B pedalboards using actual controller assignments,
  including grouped effects and inverse ranges. Unsupported timed, momentary and
  command/MIDI switches are visibly unavailable rather than partially executed.
- **Tuner mode:** requests the Stadium tuner on entry and sends its exit command when
  leaving. Known network messages do **not** expose live note/cents readings; read
  those on the Stadium display. Command acknowledgements are not pitch measurements.
- The preset browser stays on the left in every mode. Scene/stomp boards fit regular
  iPad and 12.9-inch Pro layouts without workspace scrolling; preset/model lists scroll.
- Guarded parameter/model/output changes, User Save and verified Save Copy into an
  empty slot. Backups retain native saved/live bytes before editing.
- Follow selected blocks on the pedal, receive device updates, and refresh current state.
- Bonjour device search, selection and manual address entry, including switching to
  another Stadium. The app uses your device, not a developer-specific address.
- Read library inventories: Factory/User presets, setlists, IRs, Favorites, Templates,
  Songs and the clone hierarchy reported by the device. File-based models need files.

## What is not implemented yet

Command Center assignment editing, Global EQ controls, song/Showcase editing and
transport, IR/clone file import and assignment, preset renaming after creation,
block insertion/removal, cross-row/path moves, general routing editing, snapshot renaming,
firmware updates and PIN authentication. Desktop Focus user-default management,
favorites creation and vendor equipment artwork are not implemented. Navigation for Command Center, Global EQ and Songs is present, with
unfinished sections labeled. Output destination selection is a narrower supported
operation, not a complete routing editor. Dragging leaves input/output and split/merge
nodes fixed; branch layouts that cannot be established safely are refused. Amp replacement refuses when Auto Cab
would add unexpected blocks; disable Auto Cab on the device first if appropriate.

**Offline preset editing/creation and reconnect synchronization are planned, not
shipped.** Android tablet development is planned; this repository currently ships
Swift/iPad source only. There is no phone UI. A phone version would require a
substantial interface redesign.

## Install

For nontechnical users, a TestFlight beta is being prepared; no invitation is live
yet. [Installation instructions](INSTALL.md) explain the planned tap-to-install
route and the source-build route currently available to developers.

## Connect and use

Build and sign with your own Apple developer identity, install on an iPad running
iPadOS 18 or later, allow Local Network access, and put it on the same LAN as the
Stadium with Remote Access enabled. Tap **Connect → Search Network**, select your
Stadium, or enter its hostname/IP. The connection panel remains available for
switching devices. No credentials, analytics service or cloud account are embedded.
Existing Remote Access restrictions are not bypassed.

Changes reach the pedal immediately. Use **Save** to retain them; Factory presets
require **Save Copy**. Preset recall refuses to discard unsaved edits. Snapshot
switching follows the device's Snapshot Edits behavior. Documents/"Preset Backups"
contains local backups and can contain personal preset data; keep it out of Git.
Network failure can leave a write uncertain: check the pedal before retrying.
Tuner exit cannot be guaranteed after network loss or process termination.

## Build

Requires macOS, Xcode with iOS 18+ SDK, Swift and Python 3. No third-party Swift
runtime dependencies. Choose build/cache directories appropriate to your machine;
do not put generated outputs in the repository.

```sh
swift test
python3 -m venv /path/to/dev-venv
/path/to/dev-venv/bin/pip install -r requirements-dev.txt
/path/to/dev-venv/bin/python -m unittest discover -s Tests -p '*integration*.py'
```

For an external Swift build directory, use `swift test --scratch-path /path/to/build`
and set `STADIUM_PROBE`, `STADIUM_EDIT_CHECK` to its `debug/` executables and
`STADIUM_TEST_ROOT` to a scratch directory before running Python tests.

### Local model metadata

Extracted Line 6 metadata/artwork/binaries are **not** included in this repository.
For named model browsing, Focus and editing, prepare functional metadata locally from
an installed editor you are entitled to use. The reference tools are
[Vheissu/helix-stadium-tools](https://github.com/Vheissu/helix-stadium-tools), tested
at `dad97d3a2011290f7f6630d04cc1a819cc58752b`. Its
`scripts/generate_mobile_block_types_json.py --output /private/path/blocks.json`
and `scripts/generate_io_models_json.py --output /private/path/io.json` read local
editor resources; consult that project's extraction requirements/options.

```sh
python3 Scripts/prepare_parameter_catalog.py \
  --blocks /private/path/blocks.json --io /private/path/io.json \
  --controls '/Applications/Line6/Helix Stadium.app/Contents/Resources/P35Controls.json' \
  --uidefs '/Applications/Line6/Helix Stadium.app/Contents/Resources/P35ModelUIDefs.json'
```

This creates ignored `iPad/Resources/ParameterCatalog.json`. Generic labels are
used without metadata; guessed parameter controls/model replacements are not
exposed. Do not commit extracted catalogues or vendor help/artwork.

```sh
STADIUMPAD_DEVELOPMENT_TEAM=YOUR_TEAM_ID \
STADIUMPAD_BUNDLE_ID=your.unique.stadiumpad \
python3 Scripts/generate_project.py
xcodebuild -project StadiumPad.xcodeproj -scheme StadiumPad \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /path/to/ipad-build -allowProvisioningUpdates build
```

The generated project is ignored because it contains your local signing settings.
Use your own signing/profile; no team identity or provisioning profile is published.
This is source distribution, not an App Store release or universally installable IPA.

## Contribute

Report reproducible bugs, suggest improvements or submit a PR. Include firmware,
app version, expected/actual behavior and steps to reproduce; remove private preset
and device data. Please read [CONTRIBUTING](CONTRIBUTING.md),
[SECURITY](SECURITY.md), [AI/LLM handoff](README_AI.md) and
[verification status](docs/VALIDATION.md). Public visibility permits forks and PRs,
not direct write access to this repository. Maintainers decide what merges.

MIT licensed. [Acknowledgments](ACKNOWLEDGMENTS.md) credit Dwayne Charrington's
research and implementation, Line 6's work, and the Quad Cortex/Tone Master Pro
workflow inspiration. This project is not affiliated with those manufacturers.
We hope an official Line 6 iPad editor makes StadiumPad unnecessary one day;
that hope is not a statement about their roadmap.

### Local Focus metadata

After preparing ParameterCatalog.json, generate the reference `focusModels.json`
locally using helix-stadium-tools' `scripts/generate_mobile_focus_data.py` and the
extracted factory Focus definitions. Then run:

```sh
python3 Scripts/prepare_focus_catalog.py --source /path/to/focusModels.json \
  --modeldefs /path/to/installed-editor/modeldefs/p35md-1_4_0_0.bin
```

This validates complete maps against native ids/types/ranges and adds Focus-only
controls that the normal editor layout omits. Both generated catalogues stay out
of Git. A missing/incompatible map remains unavailable; no invented tone map is
substituted. EQ displays control positions, not a live spectrum or a measured DSP
response. Cabinet coordinates use native Position/Distance with quarter-inch
Distance steps. Equipment backgrounds are original vector/SF-symbol treatments.
