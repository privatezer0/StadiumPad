# StadiumPad for Android tablets

Native Java/Android port of StadiumPad0.6.3's iPad feature set. Original dark editor
layout: persistent scrolling preset folders at left, signal chain above categories/
models and parameter controls, centered mode selector, info/save header, category
colors and blue app icon. Compact portrait uses a model chooser. Native input,
dialogs, inertial lists, accessibility nodes and Android NSD; no WebView or Mac bridge.

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
