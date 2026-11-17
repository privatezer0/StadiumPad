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
changes. Do not claim unfinished desktop features, offline sync, Android, phone
support or live tuner readings exist. Commit related source/tests/docs together;
push only to an explicitly authorized repository without force-pushing.
