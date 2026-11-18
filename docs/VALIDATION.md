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
