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

A separate public-identity Xcode archive builds successfully for TestFlight
preparation. This is not an uploaded build or approved beta invitation. App Store
Connect access, feedback/review contact information and Apple's external beta
review still need to be completed.


The App Store distribution export subsequently succeeded. The resulting IPA passed
archive integrity, expected public bundle/version/build, distribution-profile and
TestFlight entitlement checks; the DEBUG automatic-write harness is absent. This
remains a staged distribution build, not an uploaded or Apple-approved beta.


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
Physical finger-gesture qualification and final installation await reconnection of
the Pro; protocol/state/save tests are distinct from a touchscreen acceptance test.

Final checks for this source:31Swift tests and25executable loopback tests pass.
All273User presets present before the reorder test were re-read after the real
save/reload/restore run:zero SHA-256 changes. The two new test copies were the only
write destinations. The owner Release0.5.1/build8 is signed and packaged externally;
Pro reconnection is still required for final installation/finger-drag acceptance.
