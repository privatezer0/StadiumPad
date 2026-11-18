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
