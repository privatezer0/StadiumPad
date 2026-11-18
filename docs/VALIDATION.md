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
