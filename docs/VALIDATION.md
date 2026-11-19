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

## November18 — iPad Command Center 0.8.0/build17 candidate

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

**Native iPad qualification pending:** Debug0.8.0/build17 compiles and installs on
Pro, but iPadOS refuses launch while passcode-locked. The owner has been asked to
unlock it. The prepared explicit Debug harness will test actual Monitor assignment,
EXP2, snapshot control, Label/Color and persistence, then capture Command Center at
Pro/regular-landscape/portrait sizes. No native layout/touch qualification, Release
installer promotion, TestFlight upload or complete desktop parity is claimed yet.
Validated installer mirrors remain at iPad0.7.0/build16 until this gate passes.
