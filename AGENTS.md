# StadiumPad contributor rules

Read README.md and README_AI.md before changing code. Keep protocol, transaction
state and SwiftUI presentation separate. Preserve unrelated work and unknown native
data. Use typed operations, exact connection/preset/snapshot/block/model/slot
identity, metadata range/type validation, backup and readback. Never retry an
uncertain hardware write or overwrite an occupied slot to create a copy.

Hardware write tests require explicit user authorization and newly allocated spare
presets, preserving saved originals and unsaved source edits. Source/tests alone
do not prove physical-device behavior. Do not delete presets, update firmware,
bypass DSP/access restrictions or make unrelated hardware changes.

Never commit credentials, device IDs/private addresses, captures, preset data,
extracted proprietary catalogues/artwork, signing material, builds or installers.
Keep local paths/signing configurable. Retain upstream MIT notices and credit.

Run appropriate Swift and loopback tests. Inspect native tablet layouts after UI
changes. Do not claim unfinished desktop features, offline sync, phone
support or live tuner readings exist. Android qualification is recorded separately. Commit related source/tests/docs together;
push only to an explicitly authorized repository without force-pushing.

Owner preferences: selecting another preset means discard unsaved edits without a
save/copy prompt; back up saved/live native bytes locally first and retain strict
internal copy/recovery guards. Keep Hype pinned beside the selected amp/model name
whenever its native control is available, independent of parameter paging. Center
it in the available header space between the model name and ACTIVE.

Android1.2 implements EQ/Command Center/Matrix UI and typed engines; older placeholder
notes are historical. Keep USB-upstream EQ persistence marked unqualified until an
actual device-owned snapshot confirms a nonbaseline change. Never weaken readback
or write global.eq.sync to claim parity. See docs/VALIDATION and Android/README.


Device latency measurements must use an optimized build (Release, or Debug with
SWIFT_OPTIMIZATION_LEVEL=-O for the explicit read-only timing harness). Do not
attribute development-build timings to the transport without measuring it. Keep
timing diagnostics private and distinguish state reads from full edit actions.


Owner appliance override (2026-11-26): normal PedalBridge selection is Bluetooth,
no login/pairing code/link. Keep home Wi-Fi independent; each app saves its own
helper. Dedicated PedalBridge tab reports pedal online/USB/Wi-Fi state and offers
Pi-only Wi-Fi/dashboard controls plus helper-worker restart. Internal native
identity, typed transaction, backup/readback and no-replay guards remain mandatory.
Do not silently fall back from a Bluetooth helper to the LAN helper transport.
StadiumPad first; QCPad Bluetooth is deferred by the owner. BLE also shares2.4GHz;
measure actual latency. Physical Android and reboot claims require actual checks.
