# StadiumPad

An unofficial, open-source **iPad/tablet editor for Line 6 Helix Stadium**.
Connect directly over your local Wi-Fi network for editing and browsing. Clone
file transfers and library backups use the optional Mac companion. This is an early community proof of concept, not a complete replacement
for the official desktop editor.

<p align="center"><img src="iPad/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.jpg" width="220" alt="StadiumPad metallic blue app icon"></p>

## USB development candidate

Version 0.10.0 (27) adds USB-scoped editor transport and compact ¼-inch/XLR/Phones
buttons opening a pedal-style Matrix mixer popup, with navigation on the right. It is under device qualification;
**it is not a released or fully qualified USB/volume build**. USB reads and Save Copy
passed on iPad Pro, and the earlier Phones fader passed a fresh owner check.
The new popup controls and Global EQ USB confirmation still need device qualification.
See [USB/Matrix development status](docs/USB_MATRIX.md). The validated installer and
TestFlight submission remain 0.9.6 (24).

## What it does

- **Preset view:** scrolling User/Factory preset browser, expandable setlist folders,
  signal chain, named parameter controls, category/model lists, exact selected-model
  highlighting and automatic scrolling. Drag effects to rearrange occupied or empty
  positions within the same signal row. Includes Looper, FX Loop and Utility models.
- **Pinned Hype knob:** available beside the selected amp/model name whenever
  that model exposes Hype. It stays visible on every parameter page, with its
  native value readout; drag to adjust or use VoiceOver's adjustable action.
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
- The preset browser stays on the left in every Home mode. Scene/stomp boards fit regular
  iPad and 12.9-inch Pro layouts without workspace scrolling; preset/model lists scroll.
- Guarded parameter/model/output changes, User Save and verified Save Copy into an
  empty slot. Backups retain native saved/live bytes before editing.
- Two-way block selection: selecting on the pedal updates the chain, model browser
  and controls; tapping a block on the tablet selects it on the Stadium too.
  External model replacements also bring their block into view. The Follow option
  controls incoming selection; parameter/model edits continue to update both devices.
  Each tablet remembers the last selected block per device and preset. On startup
  it reads the pedal's active preset and restores that preset's local view, without
  recalling a preset or moving the pedal's selection. Missing history/removed blocks
  fall back to a valid block; new live events take priority. This is remembered view
  state, not a query of changes made on the pedal while the app was closed.
- Bonjour device search, selection and manual address entry, including switching to
  another Stadium. The app uses your device, not a developer-specific address.
- **iPad Global EQ:** full-width desktop-style graph with seven draggable colored
  bands, independent 1/4-inch/XLR/Phones EQs, band enable, frequency, gain, Q,
  6/12/18/24 dB/octave cuts, output level and bypass. Includes Copy/Paste between
  outputs, Reset, sliders, value entry and live desktop/pedal broadcasts. Settings
  apply immediately, separately from preset Save; the preset sidebar is hidden.
  The graph is a calculated preview, not an audio measurement.
- **iPad Command Center:** full-width controller map and desktop-style assignment
  inspector, with the Home preset sidebar hidden. Select Stomp A/B, 16 Instants,
  X/Y, onboard EXP1/EXP2/toe, or configured external controls. Edit Command1/2,
  Preset/Snapshot, Song, Looper, Utility, ExtAmp, MIDI and HotKey assignments using
  named choices, value sliders and numeric entry. Includes snapshot-controlled
  parameters, Copy/Paste, Copy All/Paste All, Clear/Reset All, custom stomp labels
  and LED colors. Changes remain unsaved until Save Preset. External controls are
  disabled when their jack is configured for another input type.
  This assignment editor does not extend Gig View to execute MIDI/HotKey commands;
  those commands run from the Stadium's configured physical controls.
- **Librarian layout:** a full-width workspace with Presets, Cab IRs, Favorites,
  Templates, Songs and Clones categories. Presets has separate setlist and preset
  panes, folder selection and search. The Home preset sidebar and scene/save bar
  are hidden here. Clones has category folders, nested folder navigation and search.
- **Clone files:** pair with StadiumPad Companion on your Mac to import `.clone`
  files, export originals, and create/rename/delete compatible User clone folders
  and entries. Imports preserve file bytes and refuse duplicate identities, including
  files present on the pedal but absent from its visible index. Uncertain writes
  are never automatically retried. Factory/protected content is excluded.
- **Download Library:** copy User Clones and User IR WAVs into a durable ZIP on the
  tablet, with folder metadata and per-file SHA-256 checksums. Open/share the latest
  backup from Librarian. Originals remain on Stadium; this is file storage, not
  tablet DSP or offline preset editing. Current backup limit: 256 MB.
  [Mac companion setup and limits](Companion/README.md).
- Read library inventories: Factory/User presets, setlists, IRs, Favorites, Templates,
  Songs and the clone hierarchy reported by the device. File-based models need files.

**Global EQ validation:** checked on an iPad Pro with Stadium: graph dragging is
responsive, the pedal follows, and no confirmation warnings appear. Native streaming,
commit/readback and restoration checks also preserve the current preset. Audio
measurements and persistence through a pedal power cycle remain unqualified.

## What is not implemented yet

Android Command Center and Global EQ editing, song/Showcase editing and
transport, IR file import/assignment and clone-to-block assignment, preset renaming after creation,
block insertion/removal, cross-row/path moves, general routing editing, snapshot renaming,
firmware updates and PIN authentication. Desktop Focus user-default management,
favorites creation and vendor equipment artwork are not implemented. Songs navigation remains a labeled unfinished section. Output destination selection is a narrower supported
operation, not a complete routing editor. Dragging leaves input/output and split/merge
nodes fixed; branch layouts that cannot be established safely are refused. Amp replacement refuses when Auto Cab
would add unexpected blocks; disable Auto Cab on the device first if appropriate.

**Offline preset editing/creation and reconnect synchronization are planned, not
shipped.** A native Android tablet port now accompanies the Swift/iPad source; see
[Android build and validation](Android/README.md). There is no phone UI. A phone version would require a
substantial interface redesign.

## Install

For nontechnical users, 0.9.6 (build 24) is uploaded to TestFlight and Waiting for Review;
the configured public invitation is not yet accepting testers. [Installation instructions](INSTALL.md) explain the TestFlight installation
route and the source-build route currently available to developers. Android uses
a signed APK installed through Android Files; there is no Google Play listing.

## Connect and use

Build and sign with your own Apple developer identity, install on an iPad running
iPadOS 18 or later, allow Local Network access, and put it on the same LAN as the
Stadium with Remote Access enabled. Tap **Connect → Search Network**, select your
Stadium, or enter its hostname/IP. The connection panel remains available for
switching devices. No credentials, analytics service or cloud account are embedded.
Existing Remote Access restrictions are not bypassed.

Changes reach the pedal immediately. Use **Save** to retain them; Factory presets
require **Save Copy**. Selecting another preset discards unsaved edits, as in the desktop workflow;
the saved source is unchanged and its saved/live bytes are backed up locally first. Snapshot
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
and set `STADIUM_PROBE`, `STADIUM_EDIT_CHECK`, `STADIUM_LIBRARY` to its `debug/` executables and
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
