## Android Bluetooth hardware checks - November27,2026

StadiumPad Android1.3.3(code13): actual TCL Android read checks passed. Normal
OS Bluetooth enable/nearby permission dialogs were used. Discovery now advertises
BlueZ Discoverable; Android retains its high-priority GATT link with editor streams.
No benchmarked edit-latency improvement is claimed. Saved Mac-helper route read a
live Stadium Wi-Fi snapshot and correctly reported Matrix unavailable. A separate
explicit read-only probe against the known Pi identity read39blocks, three Matrix
outputs and verified USB availability while iPad QCPad retained QC's independent
lease. Saved production helper choice remained unchanged. Different tablets can
control different pedals on one Pi; one editor per pedal remains enforced.

No pedal writes or preset recalls in this increment. Full original unsaved QC tone
(all15effects/settings) matched the private baseline. Direct Android USB and full
physical touch/write acceptance remain pending. QCPad's safe history64-entry cap
was removed with100-step regression; all-operation save/load history remains
unfinished. A helper import-path deployment regression was corrected and a clean
vendored-engine import regression added. Mac/Pi startup and packaging are checked
separately from fresh-Pi installation, which remains unqualified.

## Mac host and Android refresh — November27,2026

The new Mac Catalyst target (macOS15+, Apple silicon build) compiles the same SwiftUI/editor/transport sources as
iPad, including direct Wi-Fi/USB, Full PedalBridge and Hybrid, Matrix, Command
Center, EQ, performance views and librarian. It uses a separate Mac bundle ID and
settings; it does not replace the optional StadiumPad Companion. Android1.3.2(12)
rebuilds the current equivalent feature set with retained PedalBridge/Hybrid
support. Version numbers are platform-specific, not an indication of feature lag.

Mac: generate with `STADIUMPAD_MAC=1 STADIUMPAD_DEVELOPMENT_TEAM=YOUR_TEAM python3
Scripts/generate_project.py`, then build `StadiumPadMac.xcodeproj` for macOS /
Mac Catalyst. Use your own signing identity. The source target shares the iPad
UI rather than maintaining a separate desktop imitation. The `--desktop-preview`
argument is a local no-connect layout preview.

Validation: signed optimized Catalyst build;112 Swift tests;815 Java schema/routing
checks and8 native loopback transactions. Physical Mac/Android direct USB, radio
and live editing are not newly qualified in this session; existing Matrix/EQ
qualification limits still apply. Owner practice audio, live pedals and the Pi
service were left unchanged. Installers are development builds, not notarized
Mac/App Store or Google Play releases. No new StadiumPad TestFlight upload.

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

## Android 1.2.0/code7 — November 24, 2026

- Signed in-place install on the physical TCL 12-inch Android tablet, existing app
  identity/data/pairing retained. Real PedalBridge session: 11 read-only native checks
  pass, including current preset/scene/native-byte preservation and Matrix inventory.
- Production Java engines: 797 synthetic schema/routing checks and eight loopback
  groups pass (normal/delayed EQ commits, native flag representation, external edits,
  stale/missing receipts, command allocation guards and Matrix state/identity checks).
  Existing native core instrumentation passes15checks; Swift regression passes101.
- Native Home/EQ/Command Center views rendered at three tablet viewports; Matrix
  popup rendered with real native Views. Locked-screen captures were black, so these
  are layout renders, not evidence of visible unlocked physical-screen acceptance.
- Explicit owner-approved reversible Phones/Home tests over the helper's USB MIDI:
  pan left and Center, Mute on/off, Solo on/off independently confirmed; mixer state
  restored. No volume CC was tested because inverse dB calibration is incomplete.
- Command Center:285 live checks pass on the independently allocated spare. MIDI
  assignment/subtype, snapshot flags on/off, command clipboard, labels/colors and
  Copy All/Paste All confirmed. Exact spare stored bytes restored/reloaded; every
  pre-existing saved User preset checked unchanged. An initial post-recall context
  guard stopped before a write; a reviewed fresh context resumed on the same spare
  without allocating again or weakening the guard. Owner unsaved source tone remains
  preserved in the spare. No original was saved or overwritten.
- Global EQ frequency/gain test received ACKs but its device-owned native settings
  snapshot did not confirm the desired change. Separate absolute-baseline recovery
  confirmed restoration and unchanged active preset/native bytes. No automatic retry.
  **USB-upstream EQ persistence remains unresolved**, matching the separately noted
  unqualified USB EQ route on iPad. Native integer flags alone did not resolve it.
- Matrix direct Android USB, all57sources/outputs, sustained gesture latency and
  eight-inch physical tablet acceptance remain pending. No firmware, studio audio
  routing/default/gain changes, original preset saves or new TestFlight upload.

Earlier entries below are historical and do not supersede these limits.

---

# Verification status

Version 0.5.0, November 17, 2026. Observed hardware: Helix Stadium firmware 1.4.2;
12.9-inch iPad Pro (5th generation). Regular iPad landscape/portrait layouts are
native UIKit renders on the Pro, not physical regular-iPad usability qualification.
No other firmware, PIN authentication or acoustic/latency qualification is claimed.

## Automated

27 Swift tests cover bounded fragmented framing, OSC/MessagePack envelopes,
metadata validation, read/edit command shapes, selection events, bypass polarity,
grouped inverse assignments, unsupported switches, connection-origin propagation,
setlist reference resolution and explicit tuner open/exit envelopes.
20 loopback tests exercise the actual native executables: stale request IDs,
fragmented/multipart responses, disconnects/timeouts, edit/save/readback/copy/model
failures and successful persistence. Tests use synthetic data and loopback only.

## Native hardware

Earlier editor checks verified named parameter edits, model replacement, output
selection, snapshot switching and save/reload on newly allocated spares. Physical
pedal block selections were observed as /setSelectedBlock; the iPad matched the
block/category/exact model selection and scrolled the model list to it.

The performance harness passed 16 checks on newly allocated copies: preserve the
source, allocate a distinct test preset, create an empty scene, toggle an actual
assigned effect and restore its value, activate the new/original scene, save,
switch away/reload, verify scene persistence and restored block values, and return
to the preserved source copy. The physical switch tested had one controller;
grouped/inverse assignments have synthetic coverage, not full hardware qualification.

All 271 User presets present before that performance test were re-read and their
SHA-256 hashes remained unchanged. No existing saved preset was a write destination.
Private plans, backups, raw data and screenshots are intentionally excluded.

Connection regression: recreating the root view using an identity changed inside
connect caused repeated connection startup and cancellations. Root identity reset
was removed; local selection/dialogs are cleared on explicit connection changes,
with per-connection edit contexts. Routine UI task cancellation is not shown as an
error. Successful native performance testing followed that correction.

## Layout and limits

Native Pro and regular landscape/portrait renders inspect Preset, Scene and
Footswitch views with the sidebar retained. Scene has eight tiles; Stomp has ten
assignable switches per A/B bank. Dedicated footswitches are not simulated. Final
header centers Preset/Scene/Footswitch/Tuner, separating info/save actions.

Native iPad tuner open and exit both received successful acknowledgements; the
known property-list slvppgsm envelope is explicitly decoded and covered by a
regression check. Final native renders include the centered four-mode header and
14 actual setlist folders. No live network note/cents feed is established;
never interpret a command ACK as a tuning result. Full touchscreen/VoiceOver,
other-device network switching and regular physical-iPad acceptance remain open.

See README for unfinished desktop functions and planned offline/Android work.


## Delivered source/build

Public source commit `59177a4` was pushed and anonymously readable. The installed
owner Release0.5.0/build7 reconnected with device events and named controls; private
unsaved source edits were left unsaved. Both owner installer mirrors and complete
ten-product SHA-256 inventories were verified. Public history excludes private
research/history, device data, signing settings and extracted model metadata.

The public-identity distribution archive/export passed integrity, expected bundle,
version/build, distribution-profile and TestFlight entitlement checks; the DEBUG
automatic-write harness is absent. Updated 0.5.1/build8 was uploaded and Apple
validated it. On November 17, App Store Connect confirmed **Waiting for Review**
after external Beta App Review submission. This is not approval or a live public
invitation. See docs/TESTFLIGHT.md for current release status.

## 0.5.1 block dragging

31 Swift tests and five new executable loopback cases cover native adjacent-swap
planning, gaps/occupied cells, stale origins, fixed IO/routing boundaries, changed-
flag ACKs, preserved settings/assignments, runtime/set-order normalization, rejection,
timeout, stale-source refusal and ACK-without-readback. Existing integration checks
are run with the new build as part of delivery.

A real Stadium test resumed an independently reviewed new spare after a conservative
readback refusal. It confirmed the already-applied move without resending the batch,
saved/reloaded the rearranged chain, reversed it, saved/reloaded the original order
and settings, and returned to the preserved copy. Only two newly allocated test
copies were write destinations. Final original-preset hash audit is recorded below.
The source-copy byte guard was retained; a conservative automatic-open refusal did
not discard source edits or cause duplicate allocation.

The iPad source builds with finger drag and accessible Move left/right actions.
Release0.5.1/build8 was subsequently installed and launched on the connected Pro;
the device app inventory independently confirmed its version/build. Physical
finger-gesture qualification remains pending the requested manual drag; protocol/
state/save tests are distinct from a touchscreen acceptance test.

Final checks for this source:31Swift tests and25executable loopback tests pass.
All273User presets present before the reorder test were re-read after the real
save/reload/restore run:zero SHA-256 changes. The two new test copies were the only
write destinations. The owner Release0.5.1/build8 is signed and packaged externally;
Installation on the Pro is verified; finger-drag acceptance is still pending.

The 0.5.1 owner IPA and full installer inventories were read back and verified in
both permanent Latest Version delivery folders. The affected installer was updated;
unrelated products were preserved. Build outputs and installers remain outside Git.

For the final Release touch check, a fresh275-preset saved-content baseline was
captured privately before testing. The reviewed69C test spare was opened only
from the clean69B preserved copy. No agenda/save was sent during setup. The
physical drag result and its subsequent save/reload verification are not yet claimed.

## 0.5.2 touchscreen drag correction

The owner reported that0.5.1's touchscreen drag did not move a block. Independent
readback confirmed an unchanged chain. The block Button competed with the drag,
and gesture reset cleanup could clear its captured edit identity before onEnded.
The block now has an explicit full-cell hit area, separate tap selection and a
higher-priority drag. Gesture reset clears transient visuals without erasing the
identity needed by the drop callback. Standard accessibility activation and Move
left/right actions are retained.

The owner confirmed **“move works now”** on physical Pro Release0.5.2/build9.
Independent native readback found the expected effect moved from position2 to the
empty position1 in path1. A reviewed saved-byte hash bound the verification to the
existing test spare; the forward move was not replayed. Full model/harness values,
enabled state and assignment configuration matched. Save/switch/reload passed;
reverse move/save/switch/reload restored original order and settings. The pedal
returned to the clean preserved copy. Of275 saved presets in the fresh baseline,
**zero outside the test destination changed**. No new presets were allocated.

31Swift tests and27loopback cases pass, including observed-move save/reload/restore
with only the reverse agenda sent, and mismatched saved-byte refusal with no writes.
Native physical Pro and regular landscape/portrait renders were inspected. Regular
physical touchscreen, VoiceOver and cross-device qualification are not claimed.

The corrected owner Release0.5.2/build9 is signed, packaged and installed on Pro.
TestFlight upload/review status is tracked separately in docs/TESTFLIGHT.md.

The corrected0.5.2 IPA and both complete installer inventories were read back
with matching SHA-256 values in the permanent delivery folders. The final owner
Release was reinstalled/launched after layout inspection and app inventory confirmed
0.5.2/build9. No DEBUG harness was left installed. Apple accepted the public upload;
build8 was withdrawn from review. Apple confirmed corrected build9 is
**Waiting for Review** after external beta submission.

## 0.6.0 Focus View

Desktop Focus was inspected through the installed app without changing controls.
StadiumPad's aperture toggle replaces the chain area; presets/model choices and
ordinary controls stay visible. Named factory tones, X/Y blend, precise controls,
start-tone restoration, cabinet placement and EQ frequency/gain handles are
implemented. Factory maps are generated locally (670complete maps,369supplemental
native controls); no maps, model binaries or vendor artwork are committed.

34Swift tests pass, including60synthetic native-reference arithmetic vectors,
coordinate bounds, triangle weights and invalid metadata refusal.34executable
loopback cases pass, including discrete-before-float batching, save/reload/restore,
stale model/preset refusal, partial rejection, no retry after timeout and no save
on unconfirmed values. The 60numeric vectors come from the MIT reference's
synthetic fixtures, not user presets or native binary bytes.

The native iPad client passed13checks against a new reviewed spare: three Focus
positions on Dyhana Drive, full readback, save/switch/reload, restoration and another
reload, then return to the preserved copy. Unsaved source state was preserved in
69D, test70A only was edited; no existing saved preset was a write destination.
Physical Pro and regular landscape/portrait Focus/EQ layouts were rendered and
inspected. The owner subsequently confirmed named-tone selection and pad dragging change
the parameter controls on the Pro. Cabinet physical mic placement, VoiceOver and
all670models on hardware are not claimed tested. Desktop user-default/favorites
management and vendor photo backgrounds are not part of this implementation.

Final audit re-read all275presets present before Focus work:zero SHA-256 changes.
New69D/70A copies retained, original unsaved source preserved. Final owner Release
0.6.0/build10 installed/launched/inventory verified and mirrored to both installer
folders with full inventory readbacks. Public distribution upload and external
submission succeeded; Apple visibly confirms Waiting for Review for build10.
The owner confirmed the physical pad check. Independent full graph/settings and
assignment readback found four Focus parameter changes, confirmed save/reload,
restored the starting values, confirmed another save/reload and returned to69D.

## 0.6.1 preset selection discards unsaved edits

Owner clarified that selecting another preset means discard the unsaved changes.
The UI now opts into that behavior without a save/copy prompt. Saved and live native
bytes are backed up locally first, including state the dirty flag might omit.
Connection/source identity is rechecked after backup; the target is loaded and
independently confirmed. No source Save, SetContentData or new allocation is sent.
Internal/recovery callers keep strict loading unless they explicitly opt in.

Four focused loopback cases cover dirty discard/return with distinct saved/live
backups, strict-load refusal, backup failure and source change during backup.
A physical iPad client run passed8checks: edit the reviewed test spare without
saving, select the preserved copy, return and confirm original saved settings and
exact saved-byte identity, then leave the clean preserved copy open. No valuable
source preset was edited. The Focus touch/save/reload result above is now accepted.

Final0.6.1 verification:34Swift and38executable loopback tests pass; the final
four discard cases were rerun after tightening the source-switch-during-backup
fixture. Native discard8checks and owner-reported Focus touch plus independent
4-parameter save/reload/restore checks pass. No UI layout change was made in0.6.1.

Final owner Release0.6.1/build11 was installed and launched on Pro; independent app
inventory confirms version/build. Final275-preset saved-byte audit remains zero
changes. The preserved Focus copy is selected and clean. Both current installer
mirrors and complete inventories are refreshed/readback verified. Public archive
is built; TestFlight upload/review status is recorded separately.

## 0.6.2 pinned Hype control

The owner requested Hype beside the amp/model name, available regardless of page.
The header now resolves the live model's native Hype definition by semantic key,
not a fixed numeric id;30locally catalogued models expose it. It uses native range/
display metadata, including Off and0–10display scaling, drag-on-release editing,
readback updates and adjustable accessibility. The same control is removed from
the paged grid, preserving the other controls and page navigation.

34Swift checks and signed owner/public builds pass. Native Pro/regularlandscape/
portrait renders were inspected using the connected BritSL100; Hype and its3.4
readout sit next to the name on page1. This phase was read-only on the owner's
current preset, with no Hype edit, global AutoCab change or preset replacement.
The existing guarded parameter edit path is reused; the owner subsequently confirmed the physical Hype knob updates both iPad and
Stadium. VoiceOver acceptance is not separately claimed. Prior Focus touch and native
preset-discard checks remain passed. No saved source preset was written here.

Final0.6.2owner Release was installed/launched and independent app inventory confirms
build12. Both permanent installer folders and full10productinventories match.
Owner Hype-touch acceptance passes; Focus touch/save/reload and native discard
acceptance are complete. No remaining manual-touch question is pending. Public
0.6.2archive/upload succeeded; current beta status is tracked in TESTFLIGHT.md.

## 0.6.3 centered Hype header

The Hype knob is centered in the available space between the selected amp/model
name and ACTIVE. Native read-only Pro and regular landscape renders confirm the
placement, with the preset sidebar and controls visible. The underlying knob is
the owner-accepted control from build12; no hardware edit or Save was performed
for this layout change. Owner Release0.6.3/build13 installed/launched and device
app inventory independently confirms both version and build. Owner/public builds
and public upload succeeded. Both installer mirrors and full ten-product SHA-256
inventories passed. Prior Swift/loopback and physical touch results above apply;
no additional gesture acceptance is claimed for this spacing-only change.

Public0.6.3/build13 processed successfully and was submitted to the external group.
App Store Connect visibly confirms Waiting for Review. No approved public download
or invitation exists; automatic tester notification is disabled.

## Android0.6.3 initial native tablet port

Android validation is detailed in [Android/README.md](../Android/README.md).
Connected Android16 tablet:13native core checks include60shared Focus vectors;
synthetic edit/save/discard and five copy fault scenarios pass. Native pedal
transaction suite31checks and injected on-device touch suite34checks pass on a
new spare; final25checks cover NSD, output selection and tuner reference/exit.
Final read-only20checks cover category persistence/model auto-scroll and four
native viewport renders including compact portrait. All277pre-existing saved
User presets remain byte-identical. Unsaved source retained in a new preserve
copy; separate new test copy retained. No original preset Save/Store was sent.
Physical human finger/TalkBack/all-model qualification is not claimed. iPad source
and TestFlight review are unchanged by the Android port.

## Android0.6.4 Focus icon

Original vector aperture and FOCUS caption replace the tiny Unicode glyph. Signed
Android build passes. This is a visual/hit-region change; existing Focus gesture,
batch/readback and restoration behavior is retained. Device/layout delivery evidence
is recorded in the Android release notes after inspection.
The read-only check exposed a same-block/category-return scroll edge case; including
browser category/search in the selection key corrects it without changing hardware
operations. Presets without a Hype amp use a catalogued block for this UI check.
0.6.4 installed successfully after owner reconnection. Final read-only rerun was
interrupted by another USB disconnect; final visual check remains pending. Native
protocol checks reached18checks on preceding runs; the viewport harness now handles
compact portrait/no-Hype presets. No new parameter or preset hardware writes.
Both installer mirrors/full eleven-product inventories verified for the signed APK.
Follow-up on the paired TCL Android16 tablet completes the pending0.6.4 icon check:
wireless install/cold launch/version/process pass;20read-only checks pass. Native
landscape/portrait aperture+FOCUS renders inspected. App relaunched after tests;
no pedal/preset edits and no other application updates. Same signed APK as above.

## 2026-11-18 — 0.6.5 two-way live selection

Implemented typed `/SelectedBlockSet` requests in both native clients. Firmware1.4.2
confirms them through correlated `/setSelectedBlock` broadcasts, without `/status`.
Incoming selections apply immediately, retain a model slot at the same location,
and reconcile with fresh state. Android also follows external model replacements;
ordinary refresh still preserves model/category browsing. Stale queued external
selection cannot supersede a newer Android tap. Incoming changes never send another
selection request, preventing client feedback loops. No automatic Save or retry.

Verified in this session:

- 36Swift tests and15Java selection regressions pass.
- 44loopback cases pass, including actual Swift and Java socket sessions with
  correct, missing and wrong-command selection echoes. Missing/wrong echoes send
  only one selection request, with no parameter/model/load/save commands.
- The owner's physical pedal amp/reverb selections were independently captured
  on the live subscription stream before the update.
- Native iPad Pro DEBUG selection-only check:4checks pass for amp/reverb echo
  confirmation and actual visible editor selection. Separate client selections
  also updated the iPad's UI report to the correct amp/reverb model and category.
  Actual Pro screen inspected: chain outline, selected model highlight/scroll and
  corresponding parameter controls agree.
- Native TCL Android16 check:26checks pass, including incoming selections from
  an independent connection, model category, outgoing tablet requests/echoes,
  unchanged preset/parameters/dirty state, and four viewport renders. Actual amp
  and reverb screens inspected. These are native automated checks, not human
  finger acceptance or fresh physical model-replacement testing on every model.
- Independent readback confirms the entire preset graph stayed identical across
  the iPad/Android selection checks. No parameter/model replacement, preset Save,
  preset recall or allocation was sent. Existing unsaved edits stayed unsaved.
- Signed iPad0.6.5/build14 Release installed/launched on Pro and independently
  inventoried. Android0.6.5/code3 installed in place over paired Wi-Fi on TCL;
  package version, cold launch and live process verified. Test package removed.
  The iPlay/TableSign batch and other apps were not changed by this update.

IPA/APK signature and package integrity pass. Both permanent installer mirrors
retain all12products and pass complete SHA-256 readbacks. New installer hashes:

- iPad: `182f94785a010b74f19ee468a23e313e86a24a7762a1289465632af43309bfc2`
- Android: `265129ac0686eabaeb815c09f4cf65019b4cf7933a7b67a6cb9a3d1856b73ca8`

No new TestFlight upload/review submission or public APK release was performed.
Initial connection still chooses a local initial block until a selection event;
this update does not invent an unverified selected-block query.

## 2026-11-18 — startup selected-block query investigation

Owner requested matching the block already selected before app connection.
Read-only discovery did not establish a getter: firmware1.4.2 rejects
`/SelectedBlockGet` and `/GetSelectedBlock`;478enumerated property values and
457definitions expose no verified current-block field. Fresh command/subscription
traces include no initial selection in the normal snapshot handshake. A transparent
loopback-only trace of the installed desktop editor showed normal product/edit
buffer/property/library reads, no selection getter or initial selection notification,
and a local initial block different from the last observed pedal selection.

No startup-match feature was implemented or claimed. An undiscovered request may
still exist; these findings are bounded evidence, not proof of protocol impossibility.
Remembering the last block would not reliably reflect pedal changes made while the
app was closed, and moving the pedal's selection is not equivalent to reading it.
The temporary research proxy/listeners were stopped and the desktop retained its
direct device connection. App versions/installers remain0.6.5; no extra build or
preset/settings edits were needed for this investigation.

## 2026-11-18 — 0.6.6 remembered selection per device/preset

Owner explicitly chose remembered block selection as the startup fallback. Both
clients persist local choices per hashed device serial and actual active preset
content ID, using address/port when serial is absent. They read the pedal's active
preset before lookup: if the app last viewed A but the pedal is now on B, restore
B's own record, not A's block or preset. No record/removed/invalid/ambiguous target
uses a valid-block fallback. Within-flow moves follow internal identity and retain
model slot. Restoring is local and sends no selection, preset recall or Save.
Live events take priority; external focus is persisted after coherent refresh to
avoid attaching a transitioning preset's event to the previous preset. Preview/
fallback rendering and ordinary polling do not overwrite the preference.

Verified here:

- 43Swift tests pass, including7new device/preset-key, active-preset lookup,
  serial/address, moved/removed/ambiguous block, slot and malformed-record cases.
- 15Java selection +10new memory checks and6Swift/Java socket echo cases pass.
- Native TCL:27live checks pass, then22cold-launch checks pass. Persisted reverb
  selection restored after process stop, with the right chain/model/control view.
  Four viewport renders retained. Different-preset isolation is synthetic coverage;
  the active production preset was not recalled/switched for this test.
- Native Pro:4live checks pass; a fresh process independently reports the cached
  reverb restored on startup. Actual Pro/TCL remembered-block screens inspected.
  Final preference/focus ordering adjustment also passed Pro cold-launch check.
- Independent readback confirms the entire live preset graph stayed unchanged.
  No model/parameter edits, preset Save/recall/allocation or deletion in this task;
  existing unsaved changes remain unsaved. Selection-only live checks precede the
  local restoration checks; restoration itself makes no selection request.
- Signed0.6.6/build15 Release installed/launched/inventoried on Pro. Signed Android
  0.6.6/code4 installed wirelessly on TCL; normal cold launch/version/process checked.
  Temporary test package removed. Other apps/tablets and TableSign batch unchanged.

Both complete12product installer inventories/mirrors passed SHA-256 readbacks:

- iPad: `d3966bcd949cbd00b749a85db04efe2a08525000661b282f1597c81364e20ca5`
- Android: `c19e52e396e299748def3cbfb0cc0d4192973482ff3369a95305a306e0064915`

This does not discover the pedal's selected-block getter. If selection changes
while the app is closed, its last remembered view can differ until a live event.
Histories are local to each tablet. No new TestFlight upload/public APK release.


## November18 — 0.7.0 Librarian / Mac companion / tablet library backup

Implemented native full-width clone category/folder/search navigation on both tablet
platforms, paired file import/export and guarded folder/entry management, and
Download Library for User Clones plus IR WAVs. Correct actual mappings: Templates
-3, Favorites -8, User IRs -11, User Clones -14 with categories -22...-25.

- 50 Swift tests pass; 52 integration tests pass with three pre-existing skips;
  25 synthetic companion archive/auth/transaction/backup checks pass. Android app
  and instrumentation compile/sign. These are distinct from physical qualification.
- Installed packaged development-signed Mac companion connects to the actual pedal
  using the supported local editor. HTTPS pairing/certificate pinning works on Pro;
  wrong Stadium and wrong certificate are rejected. No vendor key is distributed.
- Native iPad exported the test clone byte-identically, imported a fresh unused
  identity into a custom spare folder and independently verified the result/job.
  Current preset, snapshot, dirty flag and complete projected blocks stayed equal.
- First upload revealed that atomic rename alone does not notify the native importer.
  The task-owned exact-hash pending file was independently reconciled once, with no
  re-upload, then placed in its spare folder. Corrected new uploads issue one
  non-truncating close-write after rename; the subsequent native Pro test passed.
  Jobs still never retry uncertain writes. Physical UUID checks also protect
  unindexed deployed assets. Earlier physical files were not all hashed before the
  first desktop import; do not claim that stronger preservation test occurred.
- Folder create/rename and same-category move were verified using task-created
  folders/clones. Incorrect copy flags were caught by readback; only the two
  resulting task-created incomplete metadata rows were independently identified and
  removed. The verified move uses last flags0,1. Existing user clones were not deleted.
- Pro Download Library saved178clones and100IRs, 7,781,278bytes. Every archive member
  matched its manifest size/SHA-256 and an independent Mac/SFTP read byte for byte.
  Original pedal files were retained; this backup predates subsequent test imports.
- Pro rendered clone Librarian at Pro, regular landscape and portrait sizes; visual
  inspection confirmed category rail, independent lists and backup buttons. Regular
  landscape fits without workspace scrolling. Portrait can abbreviate rail labels.
- Release0.7.0/build16 installed/launched on Pro after Debug verification. No preset
  recall/save/parameter/tuner/scene writes were used for this library task.

Android0.7.0/code5 is built but physical installation/HTTPS/backup/UI checks are
pending: the supplied wireless debugging endpoint closed and no USB target is
connected. Keep validated Android installer mirrors at0.6.6/code4 until qualified.
Mac helper is Apple Development signed, not Developer ID/notarized for general
public installation. No new TestFlight upload or public invitation is claimed.
IR import/assignment, clone-to-block assignment and other Librarian write functions
remain unimplemented. Complete desktop parity is not claimed.

## November18 — iPad Command Center 0.8.0/build17

Implemented full-width iPad Command Center, controller map, both stomp banks,
16Instants, X/Y, onboard EXP1/2/toe, configured external inputs, two command slots,
seven assignment families plus None, native parameter choices/ranges, snapshot
control, command/layout clipboard, reset and stomp Label/Color. Home preset/sidebar
controls are hidden in this section. Android is unchanged.

Observed reference: official desktop editor1.4.0.20 and Stadium XL firmware1.4.2.
The owner-provided screenshot and installed editor were inspected; functional
metadata is generated locally and excluded from Git. New SwiftUI vector artwork
is original. External Switch/Trigger jack modes were not changed for testing.
Their configuration gating is implemented, but those physical inputs remain
unqualified. This is assignment editing, not Gig View command execution.

- 61Swift tests pass, including source/slot restrictions, stored/wire descriptor
  differences, subtype visibility, snapshot removal casing, parameter bounds,
  property scope and narrowly permitted Toggle pairing. Five new loopback checks
  cover actual transactions, stale source rejection, command-ID ACK echoes,
  missing readback and no retry after an uncertain attachment. The complete
  integration suite passes57checks with3pre-existing Java-environment skips.
- A new preserved copy retained the initial live tone, then a second new copy was
  allocated for all edit tests. No pre-existing saved preset was a write target.
  The23-step protocol check created/switched all seven command families, edited
  MIDI CC/value, enabled/disabled snapshot control, pasted Command1 intoCommand2,
  edited/removed XY and Instant commands, cleared/pasted the full layout and
  verified Save/switch-away/reload with unchanged projected signal blocks.
- Additional hardware checks verified Command1 Toggle sets Command2 Toggle,
  leaving Toggle resets Command2 toPress, and custom label/blue LED persistence
  through Save/reload. Only the paired Action field and runtime toggle state are
  permitted to change; other command values remain protected by readback checks.
- Early checks stopped after incorrect ACK/source interpretation, snapshot-removal
  casing, stored XY/Instant descriptors and Toggle coupling. Each resulting state
  was independently read before explicitly resuming at the next confirmed step.
  No uncertain allocation/edit was blindly repeated. These fixes have regressions.
- All279User presets existing before this task were read independently afterward;
  all original SHA-256 hashes match. The pedal was returned to the preserved new
  copy. Research observer/discovery advertising stopped; desktop reconnected
  directly to the physical Stadium over Wi-Fi.

Native Pro qualification completed after the owner unlocked it:

- The explicit native Monitor harness passed18checks: MIDI value/paired Action,
  snapshot enable/disable, EXP2 create/edit/remove, custom label/blue LED, Save,
  switch-away/reload, persisted command/appearance and unchanged tone blocks.
  Tests remained confined to the previously allocated Commands Test spare.
- Actual Pro screen and native Pro/regular-landscape/portrait renders inspected.
  Initial regular render exposed a clipped bottom slider; portrait exposed a
  scaled-map offset. Corrected map layout alignment, available inspector height,
  centered heading and pedal outlines; replaced unavailable trigger symbol with
  an original vector drum. Refreshed native renders fit without workspace scrolling.
  Additional six-field Bank/Program and Note previews use a detached synthetic
  render monitor only; they do not write or replace live pedal state.
- Release0.8.0/build17 compiled, installed and cold-launched on Pro. Independent
  installed-app inventory confirms version/build; fresh normal Release monitoring
  confirms connected firmware1.4.2,20blocks,97named parameters and clean state.
  The test spare remains available for inspection. All279original hashes still match.
- Packaged development-signed IPA verified byte-for-byte against the signed app.
  Both complete13product installer inventories/readbacks passed; unrelated products
  retained. Current iPad IPA SHA-256:
  `fae7d9caa0632ba29e50d00ce21adc91fcd3b94b339540ae7c15a0b2105b158e`.

Regular-iPad sizing is native UIKit rendering on the Pro, not separate physical
regular-iPad touch qualification. External Switch/Trigger modes and all command
execution destinations are not physically qualified. Assignment editing is verified;
no complete desktop parity, new TestFlight upload or Android Command Center claim.

## November18 — iPad Global EQ 0.9.0/build18

Implemented the full-width desktop-style Global EQ workspace with the Home preset
sidebar hidden, seven colored graph handles, output tabs, band switches, frequency,
gain/Q, cut slopes, level, bypass, Copy/Paste and Reset. Controls fit Pro,
regular-landscape and portrait viewports without workspace scrolling. EQ settings
are global and apply immediately, independently of preset Save.

Validation in this session:

- Compared layout, numeric limits, enable, copy/paste and reset behavior against
  installed desktop1.4.0.20 and the official manual. Copy includes source bypass;
  Reset preserves bypass. Original global settings were captured privately first.
- 71 Swift tests passed, covering complete-schema validation, bounds, band/control
  identity, output isolation, FourCC property framing, exact reply key/status,
  batched changes, clipboard/reset semantics, live events and finite response curves.
- Full loopback suite:61 tests,58 passed/3 existing catalogue-dependent skips.
  Eight EQ scenarios cover ordered live/sync/readback, stale state, unknown fields,
  concurrent other-output edits, negative ACK, uncertain write without retries,
  ACK without matching readback and live broadcasts against stale sync reads.
-41 hardware operations passed on firmware1.4.2, across all bands/outputs, level,
  band enable, slopes, bypass, Copy/Paste, Reset and restoration. A repeated protocol
  check passed, original settings matched the private baseline, and a fresh
  connection confirmed restoration. The existing allocated spare's complete edit
  buffer, preset ID, snapshot and dirty state stayed unchanged; no preset save,
  recall or allocation was performed for EQ.
- The native iPad app running in iOS26.5 Simulator passed17 monitor/API checks
  against the real pedal, with EQ restoration and unchanged spare preset state.
  Manual app UI checks confirmed band selection, precise -0.125dB entry, stepping,
  output clipboard/paste and Reset. Independent hardware reads confirmed values.
  A desktop gain change appeared as0.1dB in the running app's actual controls;
  the test was reset afterward. Six Pro/regular/portrait low-cut/mid-band layout
  renders were inspected. The app's graph hit targets select bands; automated
  Simulator drag input did not produce movement, so physical touch-drag remains
  an explicit outstanding check rather than a claimed test pass.
- All279original saved User preset hashes still matched. Private captures/backups,
  builds and logs remained on Alian. Research proxy/discovery were stopped and the
  desktop was restored to its real device connection.

Limits: the curve is our calculated preview, not Line6 DSP or an audio measurement.
Pedal power-cycle persistence is not qualified. The physical iPad Pro was locked;
its final on-device launch/touch check requires the owner to unlock it. Android EQ
and a new TestFlight upload are outside this iPad delivery.

Release delivery:0.9.0/build18 compiled for device, passed signing and packaged-ZIP
readbacks, and installed on the Pro; device inventory confirmed that version/build.
Its final foreground launch is still blocked by the lock state described above.
The signed local IPA is present in both owner installer folders, with complete
SHA256 readbacks of all13products in each mirror. Unrelated installers were kept;
Android remains0.6.6/code4 and Mac companion remains0.7.0. No new TestFlight binary
was uploaded. Simulator-only test data was copied to Alian and the temporary app
was uninstalled from that Simulator afterward.

### November19 — physical iPad Pro unlock check

The owner unlocked the Pro. The current source Debug18 build compiled, installed
and foreground-launched successfully. Its native Global EQ Monitor harness passed
all17checks against the pedal, restored the original EQ, and preserved preset
state. Before/after independent reads matched the complete edit buffer, preset
reference and snapshot; independent EQ reads matched this session's starting
settings. No preset save/recall or new allocation occurred.

The actual Pro screen capture and on-Pro UIKit renders for Pro/regular-landscape/
portrait were inspected; band controls and level fit without workspace scrolling.
Physical touch-drag confirmation was requested from the owner after the harness;
that direct interaction remains pending, separate from the passed on-device API
and screen checks. No implementation changes or new TestFlight upload were made.


### November19 — physical-screen report and 0.9.1 candidate

Owner confirmed the graph moves on iPad but the Stadium's own Global EQ screen
stays unchanged. This narrows the failure to physical-screen propagation; no claim
about audible DSP behavior was established. Earlier ACK/sync-property tests must
not be read as proof of physical front-panel or audio-engine updates.

Candidate changes: native individual band/control properties for gestures, native
unsigned32 FourCC tags, the previously omitted `globals.eq` commit before sync
publication, and a transition check permitting only original/desired parameter
values while gesture echoes arrive. Copy/Reset keep their native whole-output path.
Debug-only private wire capture is opt-in and capped at8MiB for the next physical check.

73 Swift tests passed, EQ-targeted9 integration cases passed; full suite62 tests with
59 passed/3existing catalogue-dependent skips. New regressions enforce native live/
commit/sync ordering, refused commit without subsequent mirror publication, unsigned
key framing and partial echoes without unrelated edits. Device Debug and Release
builds compile. Debug 0.9.1/build19 installed and foreground-launched on Pro for
qualification. Physical confirmation remains pending; the candidate has not replaced
the validated release installer inventories and is not claimed to fix the pedal yet.
No preset save/recall/allocation or TestFlight upload occurred.


## November 20 — public 0.9.6 (build 24) upload and beta review submission

The already qualified 0.9.6 source was archived with public bundle identity
com.privatezero.stadiumpad, without changing the owner's installed bundle or the
validated local installer mirrors. Archive checks confirmed version/build 24,
iPad-only device family, signature, existing encryption declaration and absence of
DEBUG verification/trace markers and private preset/capture/key file types.

An expired Xcode account session stopped the first distribution attempt before
upload. After the owner completed normal Xcode authentication, automatic export/
upload succeeded once. App Store Connect processed 0.9.6 (build 24), its What to Test
was saved, and it was assigned to StadiumPad Public Beta and submitted for external
review. Live UI confirms **Waiting for Review**, not external testing availability.
Beta description and physical-hardware review notes accurately include current EQ,
Command Center and Librarian features and remaining limitations. Private review
contact details were retained without publishing them.

Public-link criteria are iPad/iPadOS 18 or later. The link was configured but its
public landing page is not yet accepting testers. No latest-version download is
claimed. Automatic tester notification is disabled; no invitations/manual tester
notifications were sent. Prior approved builds remain unchanged. Existing 73 Swift,
69 integration (3 existing skips), 12 EQ loopback and 13 native iPad checks remain the
implementation validation; no new runtime behavior changed in this upload task.
