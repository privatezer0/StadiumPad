# StadiumPad — AI / LLM contributor handoff

Give this file and README.md to your coding model. Read AGENTS.md and the actual
source before changing behavior. This guide grants no hardware or publishing access.

## Architecture

- Sources/StadiumProtocol: bounded ZMTP framing, OSC, MessagePack, typed read/edit
  commands, metadata validation, DeviceSnapshot projection, StompAssignment planning.
- Sources/StadiumNetwork: Network.framework sockets, request correlation, FIFO
  transactions, backups, edit/readback/save/copy and scene/controller operations.
- iPad/Sources: SwiftUI editor, connection monitor, discovery, scrolling folder
  browser, category/model selection, parameter controls and performance/tuner views.
- Android/app/src/main/java/com/privatezero/stadiumpad: native Java protocol, FIFO
  session/monitor, original Canvas tablet editor, Android NSD and guarded workflows.
  Build scripts use external Android SDK/JDK/build/signing paths; bundled catalogues
  are copied locally from the same generated iPad resources. No WebView or bridge
  Mac is needed. Shared synthetic Focus vectors verify arithmetic parity.
- Sources/StadiumProbe: explicitly invoked read-only research CLI.
- Sources/StadiumEditCheck: explicitly invoked spare-only edit harness.
- Tests: synthetic data and loopback peers. Hardware data is never a test fixture.

## Critical invariants

Use typed operations, never an arbitrary OSC/property-write UI. Parameter/model
contexts include connection origin, preset/snapshot, path, **visible position**,
internal block ID, model ID and model slot. Never substitute block ID for position.
Reject stale values/contexts instead of replaying them. Session snapshots are
coherent across preset/snapshot reads. Serialize whole transactions, not just frames.

Retain raw `_sbepgsm` preset bytes for preservation. Normalized FourCC maps are for
inspection; re-encoding them can corrupt native graphs. Save Copy allocates only an
empty User slot, verifies it again, records allocated identity, stores exact raw
bytes only to that allocation, and independently verifies before opening it.
Do not overwrite occupied slots. Owner-directed UI preset selection means discard
unsaved edits after backing up saved/live bytes; it does not save or create a copy.
Internal load helpers remain strict by default. Never opt copy/recovery code into
discard merely to bypass a failed preservation guard.

ACK is necessary but insufficient for parameter/model/save claims. Check actual
readback, clean state and stored content. No automatic retry after an uncertain
write. Back up saved and live state before edits. Never auto-save performance edits.

Footswitch plans resolve actual source/controller/target assignments. Preserve
inverse ranges and multi-target behavior. Commands, MIDI, timed/momentary behavior
and ambiguous targets are not supported; do not execute a partial approximation.
Tuner uses only the two known open/exit events; no live note/cents feed is established.
Do not fabricate a note meter or claim an ACK proves a pitch reading.

Disconnect/switch must invalidate old contexts, pending dialogs, inventories and
selection. Never restart a connection by recreating its owning root View with an
ID changed inside connect(): that creates a reconnect/cancellation loop. Routine
Task cancellation must not be shown as a connection error.

Native block reordering uses a bounded adjacent-swap `/doAgenda` batch within one
row, not delete/recreate. Agenda ACK's changed flag may be 0 or 1; it differs from
ordinary zero-status ACKs. Confirm the entire expected rotated layout, every model/
harness value and controller assignment configuration. Native entity/set ordering
and runtime byps/togl flags are not configuration edits. Preserve unknown fields;
never ignore actual assignment ranges or block enabled/parameter values. Reject
cross-row/path moves, IO/routing-node moves and uncertain branch boundaries.

Focus uses locally generated complete maps, float32 triangle interpolation and
strongest-point discrete choices, credited to helix-stadium-tools. Never drop a
missing non-excluded parameter and publish a partial tone. Supplemental native
controls are marked focusOnly and hidden from ordinary parameter browsing.

Batch edits validate every initial expected value before sending, retain native
backups, apply switches/integers before floats, check identity while running, and
confirm all final values. No retry/save on error. The view coalesces newer gestures
and stops queued work on close/target changes. A running batch finishes validation;
close does not abandon an uncertain write mid-response. Opening the view sends no
parameter writes. Keep start-tone restoration separate from desktop user defaults.

## Validation and delivery

Run `swift test` and Python loopback tests as documented in README. Add meaningful
regressions for behavior changed. Use native SwiftUI viewport rendering for Pro,
regular landscape and portrait when changing layout. DEBUG verification harnesses
must be explicitly invoked; Release must never auto-edit for a test.

Hardware writes require the user's explicit authorization and newly allocated spare
copies, preserving existing saved contents and unsaved source edits. Persist intent
and each allocation so interrupted tests cannot blindly allocate/retry. Audit stored
original hashes afterward. Never use production presets as write destinations.

## Public-source hygiene

Never commit credentials, signing identities/profiles, private addresses/device IDs,
traces, captures, presets, generated vendor metadata, build caches or installers.
Use configurable paths and local environment variables for signing/builds. Keep the
MIT upstream notice. Credit research accurately, including controller interpretation.

Current gaps are listed in README. Offline mode remains planned. Android tablet source is implemented; its current
qualification and remaining limits are recorded in Android/README.md. Do not
confuse a view render, an injected gesture and human physical acceptance. No cloud synchronization exists. A future
sync design needs device identities, conflict handling, explicit destinations,
backups and preservation of unknown native data before it can safely write.

## Live selection (0.6.5)

`/SelectedBlockSet ,iii [commandID, zeroBasedFlow, visiblePosition]` changes the
pedal's transient selection. It emits `/setSelectedBlock ,iiii
[source, commandID, flow, position]` on the subscription stream, with no ordinary
`/status` ACK. Keep the event reader running while the FIFO transaction waits for
the matching command ID and location, then revalidate context. A missing/wrong echo
fails without retry, Save, parameter writes or a disconnect. Do not send the incoming
`/setSelectedBlock` notification as a command. A block may contain multiple model
slots; the event has no slot field, so retain the current slot at the same location.
Never echo externally applied selection back onto the network. Incoming events apply
immediately and reconcile against the refreshed snapshot; external model changes
also select the changed visible slot. Ordinary polling must preserve category browsing.
