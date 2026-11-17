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
