## Hybrid / Full PedalBridge — November 26, 2026

- iPad1.2.0(60), Android1.3.1(11): explicit Hybrid, Full PedalBridge, direct Wi-Fi
  and USB choices; mode-specific active badge and remembered helper/mode. No startup
  settings popup after a successful saved-helper connection. Pi reverse GATT discovery
  and automatic Bluetooth MIDI were causing system pairing requests; the dedicated
  Pi now disables those and explicitly uses a nonbonding BLE control listener.
- Actual iPad → Pi BLE → Stadium USB and iPad → Mac BLE → Stadium Wi-Fi native
  snapshots/settings pass. Pi service restart and automatic fresh reconnect pass.
  Actual Hybrid direct Wi-Fi state + Pi USB Matrix-only lease pass. A DEBUG harness
  suppressing direct discovery confirms fallback to Full PedalBridge; this is not
  a claim that the physical Wi-Fi radio was disabled during qualification. In Hybrid,
  restarting the Pi worker kept the direct editor connected and automatically
  restored the USB Matrix-only lease.
- Three opt-in on-iPad XCTest checks pass: landscape home capture; switch Full↔Hybrid, relaunch with remembered
  Hybrid and no connection popup; synthetic four-second rejection shows immediate
  switch state followed by rollback. Early UI-test taps/hit targets were corrected;
  use named controls, not root normalized coordinates, to dismiss a popover.
-112 Swift tests pass, including coalescing/latest-value, acknowledged expected value,
  preset scope and failure clearing for unsent parameter gestures. Java815 schema/
  routing/intent checks +8 transaction loopbacks,25 selection/memory checks +6 native
  selection loopbacks (including pipelined snapshot equivalence) and BLE codec pass.
  Signed Android build installs/launches in emulator. No physical Android is currently
  connected; do not claim Android BLE, discovery, Matrix or new UI physical acceptance.
- Full-state polling changed750ms→5s; live updates still trigger prompt refreshes.
  Bridge snapshots pipeline fresh identity/native bytes/reference/dirty reads plus a
  trailing identity guard; cached ID/product never authorizes a tone edit. One read
  check was~0.81s pipelined vs~1.18s sequential. These are full-state read timings,
  not touch-to-pedal write latency guarantees. Pending title/order/parameter display
  remains separate from authoritative native data, backup and transaction checks.
-89 helper tests pass, including exclusive Matrix-only lease, no native edit stream
  attached to that lease, matching USB identity/channel checks and USB absence refusal.
  These transport checks did not save existing presets or write mixer settings; they
  do not replace live write qualification of every feature. QCPad BLE remains deferred.
  No TestFlight upload in this task. Pi on official PSU reports no undervoltage, but
  historical SD filesystem checksum damage remains unresolved; no mounted repair.


## Pi discovery — November 25, 2026

StadiumPad iOS 1.1.1 (51) and Android 1.2.1 (8) discover `_pedalbridge._tcp`
helpers from the connection screen. Pi advertisements can supply a dashboard
port; an explicit link opens its authenticated dashboard for the private pairing
link. Mac helpers are listed with instructions to copy their private link.
Discovery never pairs, changes a saved TLS pin/token or sends pedal commands.
Android cancels old resolver callbacks and timers when searches/routes change.

iOS device/simulator builds and 101 Swift regression tests pass. The regular-iPad
simulator screen was inspected: discovered Mac and dashboard-enabled helper entries
fit inside the connection popover. Android APK compilation/signing passes. Physical
Pi/client/AP/USB acceptance remains pending; existing hardware qualification limits
including USB EQ confirmation remain unchanged. No TestFlight upload in this task.

# Android 1.2.0 / code 7

## Android tablet update — 1.2.0 (code 7), November 24, 2026

Android now includes the current full-width Global EQ and Command Center screens,
pedal-style Matrix Mixer popup, centered core navigation with adjacent performance
icons, and automatic tuner entry/exit. Existing preset/folder browsing, scenes,
stomps, Focus, Hype, block movement and file companion remain available.
**PedalBridge support is retained**, including typed remote USB MIDI for Matrix.
Direct tablet USB MIDI is also available with explicit device identity confirmation.
Wi-Fi-only connections cannot send Matrix controls.

The physical TCL 12-inch tablet connects through the Mac helper. Bounded live
Phones/Home pan, mute and Solo on/off checks passed and were restored. EQ controls
and native transaction logic are implemented, but **EQ persistence confirmation on
the helper's USB editor route remains unqualified**: ACKs are received while the
native settings snapshot stays unchanged. Command Center assignment, parameters, scene flags, copy/paste and appearance
checks passed on a new spare, whose original bytes were restored. Pre-existing saved
User presets were independently checked unchanged. EQ test settings were restored; do not
interpret optimistic graph movement as proof. Matrix fader calibration, every
source/output combination and physical direct-USB Android operation are not fully
qualified. This development update is not a TestFlight submission or a claim of
complete desktop parity. See [validation](../docs/VALIDATION.md).

Command Center includes Stomp A/B, Instants, axes, expression/external sources,
command slots/families, metadata-defined parameters, per-scene flags, labels/colors,
and guarded command/all-command copy/paste. Unavailable physical switches and
unconfigured external jacks remain disabled. Songs is an inventory view; complete
song editing is unfinished on iPad too. The Global EQ graph is a calculated preview.

Matrix preserves the native source inventory and Home/Song horizontal expansion,
with pan, level, mute, solo, Clear Solos, output selection and guarded panel Close.
Count In is disabled when unavailable on the pedal. Level dB comes from live device
state; initial fader position is only a MIDI estimate, not a measured inverse curve.
Only a matched USB MIDI device or USB-capable authenticated helper enables writes.
Linking, stale state, missing live receipts and changed identities stop transactions.
The helper's authenticated address is retained for the connection lifetime, avoiding
mDNS lookups per gesture; a new connection resolves again and always checks TLS pin.

Synthetic regression: `Android/scripts/test-parity.sh` compiles the production Java
engines and runs schema/routing checks plus loopback-only EQ/Command/Matrix peers.
Native `ParityInstrumentation` performs read-only connected/layout checks. Explicit
live/recovery instrumentation is an owner-authorized diagnostic, not part of normal
tests; inspect its private intent and baseline before using it. Never automatically
repeat an uncertain allocation or hardware write.

---

## Historical Android 1.1 milestone

# PedalBridge development update — Android1.1.0, code6

Connection dialog adds Automatic, Wi-Fi, USB/Ethernet and PedalBridge. Pair a helper
QR/link once; pairing is encrypted with an app-only Android Keystore key. TLS checks
the pinned helper certificate and authenticates before the existing native editor
protocol. Bridge target identity must match the live snapshot. USB/Ethernet binds
each editor socket to one wired Android Network and refuses Wi-Fi fallback. Direct
USB hardware support still depends on the tablet's CDC-NCM/Ethernet support.

Build and isolated native Android tablet-emulator read-only connection to the real
Stadium through the signed Mac helper pass. Three Matrix outputs are readable over
the relay; the Android Matrix UI itself is not implemented here. Existing Global
EQ/Command Center and other documented Android feature gaps remain. Physical tablet
and direct cable qualification is pending; do not claim iPad feature parity from a
successful relay connection. Keystore/signing/history/backup identity preserved.

Explicit test runner `PedalBridgeInstrumentation` reads a temporary private pairing
from app-scoped external storage and deletes it; it only reads hardware and never
edits presets, sends MIDI or saves. Do not pass pairing tokens through adb argv/logs.

---

# StadiumPad for Android tablets

Native Java/Android tablet port of StadiumPad. Original dark editor
layout: persistent scrolling preset folders at left, signal chain above categories/
models and parameter controls, centered mode selector, info/save header, category
colors and blue app icon. Compact portrait uses a model chooser. Native input,
dialogs, inertial lists, accessibility nodes and Android NSD. Editing is direct;
optional clone-file transfers/library backups use the Mac companion.

Implemented: LAN discovery/manual connection, Factory/User folders and inventory,
model/original-inspiration search, outputs/model selection, live-follow, typed
parameter controls, centered pinned Hype, native Save/Save Copy, discard-on-recall,
within-row drag, eight scenes/empty-slot creation, assigned latched stomps A/B,
tuner activation/reference/exit, Focus named tones/XY/precise controls/restoration,
cab placement and EQ handles. The iPad's unfinished desktop functions remain
unfinished here too; see the root README. Live tuner pitch is not available.

All edits serialize whole transactions, verify connection/preset/scene/visible
position/block/model/slot and expected values, retain saved/live native backups,
and confirm readback. No uncertain write is replayed. Native bodies stay exact;
new copies only write independently allocated, rechecked empty User slots.
A changed source after copying leaves the saved copy in the library and the source
open. Hardware tests must never weaken this preservation guard to proceed.

## Build

Requires JDK17, Android SDK platform/build-tools35, Python for existing local
catalogue preparation, and the generated iPad ParameterCatalog/FocusCatalog/
ModelNames resources. No extra runtime library dependencies. The APK embeds those
local functional resources, so testers do not need extraction tools. Keep extracted
metadata, signing keys, device data and builds out of Git.

```sh
export ANDROID_TOOLS_ROOT=/external/android-tools
export STADIUMPAD_ANDROID_BUILD=/external/StadiumPadBuild
export STADIUMPAD_ANDROID_KEYSTORE=/external/private-signing/stadiumpad.jks
bash Android/scripts/build.sh
bash Android/scripts/test.sh
```

Build uses key alias `stadiumpad`; default development key creation is local only.
Preserve that key across updates. The script never uploads an APK to a public store.
Installation steps are in ../INSTALL.md. Android8/API26+; tablets, no phone layout.

## Actually verified, November17,2026

- Signed APK installed in place on the connected iPlay80miniPro Android16.
- Native protocol/data checks plus60shared synthetic Focus arithmetic vectors pass.
- Synthetic socket peer tests: edit/readback, stale expected rejection, stored Save,
  discard/reload. Five copy fault cases: normal copy, occupied slot, lost creation
  ACK with no retry/store, invalid allocated ID and corrupt copy refusal. Original
  synthetic source bytes unchanged in every case.
- Native pedal transaction suite31checks: Hype/save/reload/restore, Focus batch/
  save/reload/restore, move/reverse plus all settings/assignment verification,
  latched stomp/inverse restoration, tuner ACKs, empty scene creation/activation,
  model replacement and discard. Writes only on a newly allocated test spare.
- Native injected touch suite34checks: Hype/Focus drags, chain drag/reverse,
  scene/stomp tiles, tuner open and automatic exit on mode change, save/readback.
  This is on-device gesture testing, not a claim of human finger acceptance.
- Final25check run also verified actual Android NSD discovery, tuner reference
  retrieval and output destination change/readback/discard on the test spare.
- Model category browsing survives live refresh; selected model auto-scrolls.
  Final read-only20checks pass, including native Pro/regular/Android landscape
  and compact portrait renders. Remembered-address cold launch reconnects.
- Unsaved source preserved independently; all277pre-existing saved User presets
  remained byte-identical. The two new Android copies were retained, not deleted.

During preparation the second copy's exact-source guard correctly refused automatic
recall after source runtime bypass flags changed. Independent read-only inspection
confirmed the saved copy and configuration before explicitly recalling that already
allocated spare. No allocation or uncertain write was retried; guard remains strict.

Not exhaustively qualified: every model/firmware/Android device, physical cabinet
mic feel, full TalkBack workflow or acoustic latency. New-catalogue/native response
limits are fail-closed. Tablet UI renders and tested workflows establish the scope
above; they do not establish complete desktop editor parity.

Final owner delivery:0.6.3/code1 cold-launched and automatically reconnected to the
remembered Stadium; installed package version and live process independently
verified. Signed APK ZIP integrity passes; both permanent installer mirrors and
all eleven-product SHA-256 inventories match. APK SHA-256:
`87116a2698ee53e812d6d17d95d0ef36b84a1eb2ccb9044e0d171657b8773f9d`.
The owner installation is available now; no public APK/store publication is claimed.

## Android0.6.4/code2 — clearer Focus button

Replaces the font-dependent dot with an original vector six-blade camera aperture
and a visible FOCUS caption. A larger52×59logical-unit touch target, active color
and Open/Close Focus View accessibility labels make the toggle easier to identify.
The adjacent model-slot hit region no longer overlaps the Focus button. Protocol,
Focus tone maps and parameter behavior are unchanged; iPad remains0.6.3/build13.
Also fixes a model-browser edge case: returning to the selected block after
browsing another category/search now scrolls its model back into view even when
the block identity itself stayed the same. The read-only layout harness now also
supports presets without a Hype-equipped amp.

0.6.4 delivery: signed APK build/signature/ZIP verification passed and the update
installed on the new tablet after reconnection. The first read-only runs reached
18checks before revealing the harness's landscape/Hype assumptions on the owner's
current preset. Those assumptions are corrected for compact portrait/no-Hype;
the rerun was interrupted when USB disconnected again. Final on-device visual
inspection remains pending; no successful final screen check is claimed. No pedal
parameter/preset writes were part of this icon validation. Both installer mirrors
and complete eleven-product SHA-256 inventories verified. APK SHA-256:
`d049800d70343fc6d92b959ded4d233aefd189008e9d258d668ee3454380cf2e`.

Follow-up0.6.4 verification on the owner's second TCL9445X Android16 tablet:
wireless installation, cold launch and independent0.6.4/code2/process checks pass.
The corrected read-only suite passes20checks, including model browser behavior,
live connection/inventory and four tablet viewport renders. Native landscape and
compact portrait screenshots were visually inspected: the aperture and FOCUS label
are clearly visible. This completes the icon visual check previously interrupted
on the USB tablet. No pedal parameter, scene activation, tuner or preset-save
commands were sent during this follow-up. The temporary test package was removed;
the installed app was relaunched and retains its own settings/data.

## Android0.6.5/code3 — two-way live selection

Tablet block taps now send the Stadium's transient selection command and confirm
its correlated broadcast echo. Pedal selections update the chain/model/controls
immediately. Model replacements received elsewhere select the affected block, even
when another block was previously selected. Follow Off preserves local browsing;
ordinary refreshes leave category/search browsing intact. Selection never writes
preset settings or automatically saves. A local tap cannot be overwritten by an
older selection already queued for UI delivery; reconnect clears pending selection.

Selection regressions and actual Java socket/session tests can run on a Mac without
an emulator or tablet (requires the Android35 SDK and the Python test dependencies):

```sh
STADIUMPAD_ANDROID_BUILD=/external/StadiumPadBuild \
STADIUM_EDIT_CHECK=/external/swift-build/debug/stadium-edit-check \
PYTHON=/path/to/dev-venv/bin/python bash Android/scripts/test-selection.sh
```

The script runs15Java selection checks and six Swift/Java loopback cases covering
matching, missing and wrong-command echoes. Hardware installation/acceptance of this
update is recorded separately in docs/VALIDATION.md.

## Android0.6.6/code4 — per-preset remembered block

The local preference is scoped to the Stadium's serial and active preset content ID,
with address/port fallback when serial is unavailable. A different active preset
restores its own selection; the app never recalls the last app preset automatically.
A moved block is found by flow/internal identity/model slot. Removed or invalid
records fall back to a valid block. Startup restoration sends no hardware selection,
model/parameter change or Save. Live selections override remembered state; ordinary
polling and preview/fallback selection do not replace history. Preferences remain
local to each tablet and survive in-place app updates.

43Swift tests and10additional Java memory checks cover device/preset isolation,
active-preset lookup, address changes, moved/removed blocks, model slots and corrupt
records. The selection script also retains15selection and six socket echo cases.
Current physical installation/cold-launch checks are recorded in docs/VALIDATION.md.

## 0.7.0/code5 — Librarian and file companion

The full-width Librarian hides the Home preset sidebar and mode bar. Native clone
category/folder navigation, search, import/export and guarded User folder/entry
management match the iPad workflow. Pair using the Mac companion's QR/link. Pairing
is protected with Android Keystore-backed encryption; HTTPS pins its certificate.
Download Library retains an original-file ZIP of User Clones and User IR WAVs in
private tablet storage; Open Tablet Backup exports it through Android's file picker.
Checksums are verified before retention. No pedal originals are removed.

Templates is container -3, Favorites -8, User IRs -11. Other Librarian write actions,
IR import/assignment and clone-to-block assignment remain unavailable. See
[companion setup](../Companion/README.md). Current physical qualification is recorded
in docs/VALIDATION.md; compilation alone is not physical tablet acceptance.


## Matrix USB entry guard — November 26, 2026

The top Matrix Mixer icon is gray when the current connection has no usable USB
Matrix transport. Tapping it explains: “Stadium must be connected via USB to either
PedalBridge or your tablet to use Matrix Mixer.” It does not open the popup, exit
tuner mode or send pedal commands. Direct tablet USB still requires the existing
identity confirmation before controls can write; bridged access uses the helper's
verified Matrix capability. A connection/USB loss dismisses the iPad sheet.

iPad 1.1.1 (52) builds and is installed on the owner's Pro. The unavailable-entry
UI test passed; simulator layouts inspected. 102 Swift tests pass. Android1.2.2
(code9) builds/signs, passes809 schema/routing checks plus8 loopback transaction
tests, and its gray navigation was inspected on the emulator. The physical Android
tablet was not available for this install. No live Matrix write test or TestFlight
upload was performed. Physical iPad read-only diagnostics confirm a PedalBridge
Wi-Fi connection,20 blocks and incoming events after the helper recovery.


## Bluetooth helper — 1.3.0 (10)

Connection → PedalBridge lists nearby Mac/Pi BLE helpers. Tap to connect without
copying a link. Bluetooth editor transport requires Android10+; older supported
Android versions retain direct Stadium networking. Android12+ requests Nearby
Devices; Android10/11 requires its legacy discovery permission. Wi-Fi is unchanged.
One LE CoC link multiplexes native SUB/DEALER, Matrix and helper settings. Expanded
frames/queues are bounded; compressed native bytes stay lossless. Settings has
Status/Pi Wi-Fi/Troubleshooting sections and worker restart, with Mac networking
left to macOS. APK/signature/codec checks pass. No physical Android BLE qualification
is claimed while neither owner tablet is connected. QCPad is a separate future step.
